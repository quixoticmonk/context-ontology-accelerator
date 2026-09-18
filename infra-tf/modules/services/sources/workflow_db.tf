# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Database pipeline orchestration:
#   - Step Functions state machine (dbScan)
#   - EventBridge reaper rule (terminal-status safety net)
#   - SQS → dbTriggerFn event source mapping
#
# The state machine chain:
#   UpdateDiscovering → DbDiscovery → DbFederation → UpdateEnriching
#   → DbEnrichment → UpdateCompleted
#
# Any step's catch → dbErrorChain (UpdateFailed → UpdateSourceScanFailed
# → Fail). DbEnrichment has a catchable per-task taskTimeout below the
# state-machine timeout so States.Timeout is caught rather than firing
# ExecutionTimedOut (which cannot be caught in-machine).

# ═════════════════════════════════════════════════════════════════════
#  SFN role
# ═════════════════════════════════════════════════════════════════════

data "aws_iam_policy_document" "sfn_db_scan_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "sfn_db_scan" {
  name               = "${var.name_prefix}-sources-db-scan-sfn"
  assume_role_policy = data.aws_iam_policy_document.sfn_db_scan_trust.json
  tags               = local.tags
}

data "aws_iam_policy_document" "sfn_db_scan" {
  # Invoke the two Lambdas in the chain.
  statement {
    actions = ["lambda:InvokeFunction"]
    resources = [
      aws_lambda_function.db_connector.arn,
      "${aws_lambda_function.db_connector.arn}:*",
      aws_lambda_function.federation_provisioner.arn,
      "${aws_lambda_function.federation_provisioner.arn}:*",
    ]
  }

  # Run the enrichment task (RunTask + sync integration pattern).
  statement {
    actions   = ["ecs:RunTask"]
    resources = [aws_ecs_task_definition.db_enrichment.arn]
  }

  # Sync integration pattern needs Stop + Describe.
  statement {
    actions = ["ecs:StopTask", "ecs:DescribeTasks"]
    resources = [
      "arn:${data.aws_partition.current.partition}:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:task/*",
    ]
  }

  # Pass the task + execution roles to ECS.
  statement {
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.db_enrichment_task.arn,
      aws_iam_role.db_enrichment_execution.arn,
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  # sync integration pattern: SFN emits + receives task-state events.
  statement {
    actions = [
      "events:PutTargets", "events:PutRule",
      "events:DescribeRule",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:events:${var.region}:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForECSTaskRule",
    ]
  }

  # In-flight DDB updates against sources + source-scan-jobs (status).
  statement {
    actions = [
      "dynamodb:UpdateItem", "dynamodb:PutItem", "dynamodb:GetItem",
    ]
    resources = [
      aws_dynamodb_table.sources.arn,
      aws_dynamodb_table.source_scan_jobs.arn,
    ]
  }

  # X-Ray tracing.
  statement {
    actions = [
      "xray:PutTraceSegments", "xray:PutTelemetryRecords",
      "xray:GetSamplingRules", "xray:GetSamplingTargets",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "sfn_db_scan" {
  name   = "${var.name_prefix}-sources-db-scan-sfn-policy"
  policy = data.aws_iam_policy_document.sfn_db_scan.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "sfn_db_scan" {
  role       = aws_iam_role.sfn_db_scan.name
  policy_arn = aws_iam_policy.sfn_db_scan.arn
}

# ═════════════════════════════════════════════════════════════════════
#  State machine definition
# ═════════════════════════════════════════════════════════════════════

locals {
  db_scan_definition_final = {
    Comment = "Sources database scan + enrichment pipeline"
    StartAt = "DbUpdateStatusDiscovering"

    States = merge(
      # Status-update states (source-scan-jobs table).
      {
        for pair in [
          { key = "DbUpdateStatusDiscovering", status = "DISCOVERING", next = "DbDiscovery" },
          { key = "DbUpdateStatusEnriching", status = "ENRICHING", next = "DbEnrichment" },
          { key = "DbUpdateStatusCompleted", status = "COMPLETED", next = null },
          { key = "DbUpdateStatusFailed", status = "FAILED", next = "DbUpdateSourceStatusScanFailed" },
          ] : pair.key => merge(
          {
            Type     = "Task"
            Resource = "arn:${data.aws_partition.current.partition}:states:::dynamodb:updateItem"
            Parameters = {
              TableName = aws_dynamodb_table.source_scan_jobs.name
              Key = {
                PK = { "S.$" = "$.scanJobPK" }
                SK = { "S.$" = "$.scanJobSK" }
              }
              UpdateExpression         = "SET #s = :s, #u = :u"
              ExpressionAttributeNames = { "#s" = "status", "#u" = "updatedAt" }
              ExpressionAttributeValues = {
                ":s" = { S = pair.status }
                ":u" = { "S.$" = "$$.State.EnteredTime" }
              }
            }
            ResultPath = null
          },
          pair.next != null ? { Next = pair.next } : { End = true },
        )
      },

      # Lambda + ECS task states.
      {
        DbDiscovery = {
          Type     = "Task"
          Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
          Parameters = {
            FunctionName = aws_lambda_function.db_connector.arn
            "Payload.$"  = "$"
          }
          # Keep the Lambda envelope's `Payload` key intact under
          # $.discoveryResult so downstream states can read
          # $.discoveryResult.Payload.<field> — mirrors CDK exactly and
          # what the rescan routing on DbEnrichment expects. Renaming
          # the key would silently break that JSONPath and fail every
          # re-scan the moment application code lands.
          ResultSelector = { "Payload.$" = "$.Payload" }
          ResultPath     = "$.discoveryResult"
          Retry = [{
            ErrorEquals     = ["Lambda.TooManyRequestsException", "Lambda.SdkClientException"]
            MaxAttempts     = 3
            BackoffRate     = 2
            IntervalSeconds = 5
          }]
          Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "DbUpdateStatusFailed" }]
          Next  = "DbFederation"
        }
        DbFederation = {
          Type     = "Task"
          Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
          Parameters = {
            FunctionName = aws_lambda_function.federation_provisioner.arn
            "Payload.$"  = "$"
          }
          ResultSelector = { "federationResult.$" = "$.Payload" }
          ResultPath     = "$.federationResult"
          Retry = [{
            ErrorEquals     = ["States.ALL"]
            MaxAttempts     = 2
            BackoffRate     = 2
            IntervalSeconds = 5
          }]
          Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "DbUpdateStatusFailed" }]
          Next  = "DbUpdateStatusEnriching"
        }
        DbEnrichment = {
          Type     = "Task"
          Resource = "arn:${data.aws_partition.current.partition}:states:::ecs:runTask.sync"
          Parameters = {
            Cluster        = aws_ecs_cluster.db_enrichment.arn
            TaskDefinition = aws_ecs_task_definition.db_enrichment.arn
            LaunchType     = "FARGATE"
            NetworkConfiguration = {
              AwsvpcConfiguration = {
                Subnets        = var.private_subnet_ids
                SecurityGroups = [var.ecs_security_group_id]
                AssignPublicIp = "DISABLED"
              }
            }
            Overrides = {
              ContainerOverrides = [{
                Name = "${var.name_prefix}-sources-db-enrichment-agent"
                Environment = [
                  { Name = "DATASOURCE_ID", "Value.$" = "$.datasourceId" },
                  { Name = "SCAN_JOB_ID", "Value.$" = "$.scanJobId" },
                  { Name = "SCAN_JOB_SK", "Value.$" = "$.scanJobSK" },
                  { Name = "NAMESPACE_ID", "Value.$" = "$.namespaceId" },
                  { Name = "SCAN_TYPE", "Value.$" = "$.scanType" },
                  # Re-scan marker (string "true"/"false", always
                  # present in the execution input via the trigger).
                  # Routes the terminal source status to RESCAN_REVIEW
                  # when a re-scan of an approved source completes,
                  # instead of PENDING_REVIEW.
                  { Name = "IS_RESCAN", "Value.$" = "$.isRescan" },
                  # No-drift signal from discovery (string "true"/
                  # "false", always present in its result). When a
                  # re-scan reports "false" — no drift and no carried-
                  # forward orphaned tables — enrichment returns the
                  # source straight to APPROVED instead of parking it
                  # in RESCAN_REVIEW. Path matches CDK's:
                  # DbDiscovery's ResultSelector keeps the Payload key
                  # intact so reviewNeeded lives at
                  # $.discoveryResult.Payload.reviewNeeded.
                  { Name = "RESCAN_REVIEW_NEEDED", "Value.$" = "$.discoveryResult.Payload.reviewNeeded" },
                ]
              }]
            }
          }
          ResultPath     = "$.enrichmentResult"
          TimeoutSeconds = var.db_scan_enrichment_timeout_minutes * 60
          Retry = [{
            ErrorEquals     = ["ECS.ServiceException", "ECS.AmazonECSException"]
            MaxAttempts     = 3
            BackoffRate     = 2
            IntervalSeconds = 30
          }]
          Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "DbUpdateStatusFailed" }]
          Next  = "DbUpdateStatusCompleted"
        }
        DbUpdateSourceStatusScanFailed = {
          Type     = "Task"
          Resource = "arn:${data.aws_partition.current.partition}:states:::dynamodb:updateItem"
          Parameters = {
            TableName = aws_dynamodb_table.sources.name
            Key = {
              PK = { "S.$" = "States.Format('NS#{}', $.namespaceId)" }
              SK = { "S.$" = "States.Format('SRC#{}', $.sourceId)" }
            }
            UpdateExpression = "SET #s = :s, #u = :u, #l = :l"
            ExpressionAttributeNames = {
              "#s" = "status"
              "#u" = "updatedAt"
              "#l" = "lastScanJobId"
            }
            ExpressionAttributeValues = {
              ":s" = { S = "SCAN_FAILED" }
              ":u" = { "S.$" = "$$.State.EnteredTime" }
              ":l" = { "S.$" = "$.scanJobSK" }
            }
          }
          ResultPath = null
          Next       = "DbScanFailed"
        }
        DbScanFailed = {
          Type  = "Fail"
          Cause = "Scan pipeline failed"
          Error = "ScanError"
        }
      },
    )
  }
}

resource "aws_sfn_state_machine" "db_scan" {
  name       = "${var.name_prefix}-sources-db-scan-pipeline"
  role_arn   = aws_iam_role.sfn_db_scan.arn
  definition = jsonencode(local.db_scan_definition_final)

  # State-machine timeout: enrichment taskTimeout + 2 min so the
  # catchable States.Timeout always fires first.
  # Note: aws_sfn_state_machine takes timeout as a top-level field.
  # (Not applicable — omit; the per-task TimeoutSeconds in the ASL
  # is the reliable path.)

  tracing_configuration {
    enabled = true
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  EventBridge reaper rule — terminal-status safety net
# ═════════════════════════════════════════════════════════════════════
# Fires the reaper on ExecutionTimedOut / Aborted / Failed (statuses
# no in-machine state can catch). Reaper is idempotent — no-ops unless
# source is still in an active status.

resource "aws_cloudwatch_event_rule" "db_scan_reaper" {
  name        = "${var.name_prefix}-sources-db-scan-reaper"
  description = "Fires the db-scan reaper on terminal SFN execution statuses"

  event_pattern = jsonencode({
    source        = ["aws.states"]
    "detail-type" = ["Step Functions Execution Status Change"]
    detail = {
      stateMachineArn = [aws_sfn_state_machine.db_scan.arn]
      status          = ["TIMED_OUT", "ABORTED", "FAILED"]
    }
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "db_scan_reaper" {
  rule      = aws_cloudwatch_event_rule.db_scan_reaper.name
  target_id = "DbScanReaperLambda"
  arn       = aws_lambda_function.db_scan_reaper.arn
}

resource "aws_lambda_permission" "db_scan_reaper_events" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.db_scan_reaper.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.db_scan_reaper.arn
}

# ═════════════════════════════════════════════════════════════════════
#  SQS → dbTriggerFn event source mapping
# ═════════════════════════════════════════════════════════════════════

resource "aws_lambda_event_source_mapping" "db_scan_trigger" {
  event_source_arn                   = aws_sqs_queue.db_scan.arn
  function_name                      = aws_lambda_function.db_scan_trigger.arn
  batch_size                         = 1
  maximum_batching_window_in_seconds = 0

  scaling_config {
    maximum_concurrency = 5
  }
}

# ═════════════════════════════════════════════════════════════════════
#  SQS → bulkReviewWorkerFn event source mapping
# ═════════════════════════════════════════════════════════════════════

resource "aws_lambda_event_source_mapping" "bulk_review_worker" {
  event_source_arn                   = aws_sqs_queue.bulk_review.arn
  function_name                      = aws_lambda_function.bulk_review_worker.arn
  batch_size                         = 1
  maximum_batching_window_in_seconds = 0

  scaling_config {
    maximum_concurrency = 5
  }
}
