# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# v0.3.5 additions — three cooperating pieces that extend the sources
# surface without altering the existing API Lambda's hot path:
#   1. source-delete worker Lambda      — drains the SQS introduced by
#      the async DELETE flow (16-min envelope for DataZone teardown)
#   2. glue-event rescan Lambda         — drains the SQS fed by per-
#      source EventBridge rules the API creates at runtime
#   3. rescan scheduler role + group    — EventBridge Scheduler assumes
#      the role to invoke the API Lambda on cron/rate schedules
#
# All three reuse the shared `sources_zip_path` artifact: the handlers
# live under `packages/sources/src/coa_sources/...` and ship in that one
# zip, so the only per-Lambda difference is the handler string.

# ═════════════════════════════════════════════════════════════════════
#  1. Source-delete worker Lambda
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "source_delete_worker" {
  name               = "${var.name_prefix}-sources-delete-worker-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "source_delete_worker_vpc" {
  role       = aws_iam_role.source_delete_worker.name
  policy_arn = data.aws_iam_policy.lambda_vpc_access.arn
}

data "aws_iam_policy_document" "source_delete_worker" {
  # DynamoDB — sources (read+write; DELETE_FAILED transitions, row delete,
  # platform catalog-claim release) + namespaces (read; dataZoneProjectId
  # resolution) + source-scan-jobs (read+write; drop this source's scan rows).
  statement {
    sid = "SourcesTable"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan",
      "dynamodb:BatchGetItem", "dynamodb:BatchWriteItem",
      "dynamodb:TransactWriteItems",
    ]
    resources = [
      aws_dynamodb_table.sources.arn,
      "${aws_dynamodb_table.sources.arn}/index/*",
      aws_dynamodb_table.source_scan_jobs.arn,
      "${aws_dynamodb_table.source_scan_jobs.arn}/index/*",
    ]
  }

  statement {
    sid = "NamespacesTable"
    actions = [
      "dynamodb:GetItem", "dynamodb:Query",
    ]
    resources = [var.namespaces_table_arn]
  }

  # Assume the shared project-access role for DataZone asset deletion.
  statement {
    sid       = "AssumeProjectAccessRole"
    actions   = ["sts:AssumeRole"]
    resources = [var.smus_project_access_role_arn]
  }

  # SQS poll permissions for the event source mapping.
  statement {
    sid = "SqsPoll"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility",
    ]
    resources = [aws_sqs_queue.source_delete.arn]
  }
}

resource "aws_iam_policy" "source_delete_worker" {
  name   = "${var.name_prefix}-sources-delete-worker-policy"
  policy = data.aws_iam_policy_document.source_delete_worker.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "source_delete_worker" {
  role       = aws_iam_role.source_delete_worker.name
  policy_arn = aws_iam_policy.source_delete_worker.arn
}

resource "aws_lambda_function" "source_delete_worker" {
  function_name    = "${var.name_prefix}-sources-delete-worker"
  role             = aws_iam_role.source_delete_worker.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "coa_sources.api.source_deletion_worker.handler"
  filename         = var.sources_zip_path
  source_code_hash = local.sources_zip_hash
  timeout          = 900 # 15 minutes (vs API's 30s — the whole point)
  memory_size      = 512

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      SOURCES_TABLE           = aws_dynamodb_table.sources.name
      NAMESPACES_TABLE        = var.namespaces_table_name
      SOURCE_SCAN_JOBS_TABLE  = aws_dynamodb_table.source_scan_jobs.name
      SMUS_DOMAIN_ID          = var.smus_domain_id
      PROJECT_ACCESS_ROLE_ARN = var.smus_project_access_role_arn
      # Worker derives the source's catalog name from its id using the same
      # derivation as the API — needs the same prefix the API is given.
      RESOURCE_PREFIX = "${var.name_prefix}-"
      # Default cleanup budget tracks the 30s API path; raise it almost to the
      # 900s envelope (60s margin) so an 860-table teardown can actually finish.
      DATAZONE_CLEANUP_BUDGET_S = "840"
    }
  }

  tags = local.tags
}

# Event source mapping. batchSize=1 and maxConcurrency=5 match CDK — one
# source per invocation, capped to protect account-wide DataZone limits.
resource "aws_lambda_event_source_mapping" "source_delete" {
  function_name           = aws_lambda_function.source_delete_worker.arn
  event_source_arn        = aws_sqs_queue.source_delete.arn
  batch_size              = 1
  function_response_types = ["ReportBatchItemFailures"]
  scaling_config {
    maximum_concurrency = 5
  }

  depends_on = [aws_iam_role_policy_attachment.source_delete_worker]
}

# ═════════════════════════════════════════════════════════════════════
#  2. Glue-event rescan Lambda
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "glue_event_rescan" {
  name               = "${var.name_prefix}-sources-glue-event-rescan-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "glue_event_rescan_vpc" {
  role       = aws_iam_role.glue_event_rescan.name
  policy_arn = data.aws_iam_policy.lambda_vpc_access.arn
}

data "aws_iam_policy_document" "glue_event_rescan" {
  statement {
    sid = "SourcesAndScanJobsTables"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "dynamodb:Query", "dynamodb:Scan",
    ]
    resources = [
      aws_dynamodb_table.sources.arn,
      "${aws_dynamodb_table.sources.arn}/index/*",
      aws_dynamodb_table.source_scan_jobs.arn,
      "${aws_dynamodb_table.source_scan_jobs.arn}/index/*",
    ]
  }

  statement {
    sid       = "ScanQueueSend"
    actions   = ["sqs:SendMessage", "sqs:GetQueueAttributes"]
    resources = [aws_sqs_queue.db_scan.arn]
  }

  statement {
    sid = "GlueEventQueuePoll"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ChangeMessageVisibility",
    ]
    resources = [aws_sqs_queue.glue_event.arn]
  }
}

resource "aws_iam_policy" "glue_event_rescan" {
  name   = "${var.name_prefix}-sources-glue-event-rescan-policy"
  policy = data.aws_iam_policy_document.glue_event_rescan.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "glue_event_rescan" {
  role       = aws_iam_role.glue_event_rescan.name
  policy_arn = aws_iam_policy.glue_event_rescan.arn
}

resource "aws_lambda_function" "glue_event_rescan" {
  function_name    = "${var.name_prefix}-sources-glue-event-rescan"
  role             = aws_iam_role.glue_event_rescan.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "coa_sources.database.glue_event_rescan_handler.handler"
  filename         = var.sources_zip_path
  source_code_hash = local.sources_zip_hash
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      SOURCES_TABLE          = aws_dynamodb_table.sources.name
      SOURCE_SCAN_JOBS_TABLE = aws_dynamodb_table.source_scan_jobs.name
      SCAN_QUEUE_URL         = aws_sqs_queue.db_scan.url
      # api_response raises without this. No HTTP caller here, but the shared
      # response builder expects it.
      ALLOWED_ORIGIN = var.allowed_origin
    }
  }

  tags = local.tags
}

resource "aws_lambda_event_source_mapping" "glue_event_rescan" {
  function_name           = aws_lambda_function.glue_event_rescan.arn
  event_source_arn        = aws_sqs_queue.glue_event.arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]
  scaling_config {
    maximum_concurrency = 5
  }

  depends_on = [aws_iam_role_policy_attachment.glue_event_rescan]
}

# ═════════════════════════════════════════════════════════════════════
#  3. Rescan scheduler role + group
# ═════════════════════════════════════════════════════════════════════
# The sources-api Lambda creates/updates/deletes per-source schedules in
# this group at runtime, and passes `rescan_scheduler.arn` to them as
# the schedule's target-role (EventBridge Scheduler then assumes it to
# invoke the API Lambda, which handles the resulting scheduled event
# the same way as a cron-driven rescan).

resource "aws_scheduler_schedule_group" "rescan" {
  name = "${var.name_prefix}-sources-rescan"
  tags = local.tags
}

data "aws_iam_policy_document" "rescan_scheduler_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rescan_scheduler" {
  name               = "${var.name_prefix}-sources-rescan-scheduler"
  assume_role_policy = data.aws_iam_policy_document.rescan_scheduler_trust.json
  description        = "Assumed by EventBridge Scheduler to invoke the Sources API Lambda for recurring rescans."
  tags               = local.tags
}

data "aws_iam_policy_document" "rescan_scheduler" {
  statement {
    sid       = "InvokeSourcesApi"
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.sources_api.arn, "${aws_lambda_function.sources_api.arn}:*"]
  }
}

resource "aws_iam_policy" "rescan_scheduler" {
  name   = "${var.name_prefix}-sources-rescan-scheduler-policy"
  policy = data.aws_iam_policy_document.rescan_scheduler.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "rescan_scheduler" {
  role       = aws_iam_role.rescan_scheduler.name
  policy_arn = aws_iam_policy.rescan_scheduler.arn
}
