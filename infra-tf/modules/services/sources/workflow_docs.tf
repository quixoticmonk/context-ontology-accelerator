# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Documents pipeline orchestration:
#   - docIngestion Step Function (ingestion)
#   - docDeletion  Step Function (teardown)
#   - AOSS data access policy for kg-build task role
#   - SQS → docTrigger event source mapping

# ═════════════════════════════════════════════════════════════════════
#  AOSS data access policy (kg-build task role + account root)
# ═════════════════════════════════════════════════════════════════════

resource "aws_opensearchserverless_access_policy" "sources_ingestion" {
  name = "${var.name_prefix}-src-ingestion-access"
  type = "data"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index"
          Resource     = ["index/${var.opensearch_collection_name}/*"]
          Permission = [
            "aoss:CreateIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:DeleteIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument",
          ]
        },
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.opensearch_collection_name}"]
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DescribeCollectionItems",
            "aoss:UpdateCollectionItems",
          ]
        },
      ]
      Principal = [
        aws_iam_role.kg_build_task.arn,
      ]
    }
  ])
}

# ═════════════════════════════════════════════════════════════════════
#  docIngestion state machine
# ═════════════════════════════════════════════════════════════════════
# Chain (from CDK docIngestionStateMachine):
#   UpdateIngesting → PreProcessing → SavePreprocessingResults →
#     Choice PreprocessingSucceeded?
#       - SCAN_FAILED → PreprocessingAllFailed (Fail)
#       - otherwise   → KGBuild → UpdateCompleted (End)
#     Any error → UpdateFailed → IngestionFailed (Fail)
#
# Timeout: 24 hours.

locals {
  # Common status-update template — matches makeDocStatusUpdate in CDK.
  # Uses `$.namespace_id` and `$.doc_source_id` from state input.
  #
  # Optional `include_error`: adds `#e = :e` to the UpdateExpression
  # for FAILED terminals so the errorMessage is persisted.
  #
  # Optional `keep_reason` (COA v0.3.11): the KG-build task records its own
  # reason before it exits non-zero (SCAN_FAILED with an errorMessage such as
  # "All documents quarantined"). The generic failure write would replace that
  # reason with the ECS task description, so it runs only while the source is
  # not SCAN_FAILED yet. DocUpdateStatusIngesting sets SCANNING at the start of
  # every run, so a SCAN_FAILED seen here was written during this run.
  # attribute_exists(PK) stops the write from re-creating a source deleted
  # mid-run as a stub row, since `<>` is also true for a missing item. A
  # refused condition is the expected outcome and is never retried; any other
  # UpdateItem error (throttling, a service fault) is retried, because nothing
  # else moves a document source out of SCANNING. The condition also makes a
  # retry safe: if an attempt wrote and still returned an error, the retry
  # finds SCAN_FAILED and is refused.
  doc_status_update = {
    for entry in [
      { key = "DocUpdateStatusIngesting", status = "SCANNING", include_error = false, keep_reason = false, next = "SourcesPreProcessing" },
      { key = "DocUpdateStatusCompleted", status = "COMPLETED", include_error = false, keep_reason = false, next = null },
      { key = "DocUpdateStatusFailed", status = "SCAN_FAILED", include_error = true, keep_reason = true, next = "DocIngestionFailed" },
      { key = "DocUpdateStatusDeleteFailed", status = "DELETE_FAILED", include_error = true, keep_reason = false, next = "DocDeletionFailed" },
      ] : entry.key => merge(
      {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::dynamodb:updateItem"
        Parameters = merge(
          {
            TableName = aws_dynamodb_table.sources.name
            Key = {
              PK = { "S.$" = "States.Format('NS#{}', $.namespace_id)" }
              SK = { "S.$" = "States.Format('SRC#{}', $.doc_source_id)" }
            }
            UpdateExpression = entry.include_error ? "SET #s = :s, #u = :u, #e = :e" : "SET #s = :s, #u = :u"
            ExpressionAttributeNames = entry.include_error ? {
              "#s" = "status", "#u" = "updatedAt", "#e" = "errorMessage"
              } : {
              "#s" = "status", "#u" = "updatedAt"
            }
            ExpressionAttributeValues = entry.include_error ? {
              ":s" = { S = entry.status }
              ":u" = { "S.$" = "$$.State.EnteredTime" }
              ":e" = { "S.$" = "$.error.Cause" }
              } : {
              ":s" = { S = entry.status }
              ":u" = { "S.$" = "$$.State.EnteredTime" }
            }
          },
          { for k, v in { ConditionExpression = "attribute_exists(PK) AND #s <> :s" } : k => v if entry.keep_reason },
        )
        ResultPath = null
      },
      # for/if instead of `cond ? {...} : {}`: HCL requires both branches of a
      # conditional to have the same object type.
      {
        for k, v in {
          Retry = [
            { ErrorEquals = ["DynamoDB.ConditionalCheckFailedException"], MaxAttempts = 0 },
            { ErrorEquals = ["States.ALL"], MaxAttempts = 3, BackoffRate = 2, IntervalSeconds = 2 },
          ]
          Catch = [
            { ErrorEquals = ["DynamoDB.ConditionalCheckFailedException"], ResultPath = "$.failureReasonKept", Next = entry.next },
          ]
        } : k => v if entry.keep_reason
      },
      entry.next != null ? { Next = entry.next } : { End = true },
    )
  }

  # Ingestion pipeline only uses three of the shared status-update states.
  # DocUpdateStatusDeleteFailed (which transitions to DocDeletionFailed —
  # a state that only exists in doc_deletion_definition) is excluded so
  # Step Functions doesn't complain about an unresolvable Next target.
  doc_ingestion_status_updates = {
    for key in ["DocUpdateStatusIngesting", "DocUpdateStatusCompleted", "DocUpdateStatusFailed"] :
    key => local.doc_status_update[key]
  }

  doc_ingestion_definition = {
    Comment = "Sources documents ingestion pipeline"
    StartAt = "DocUpdateStatusIngesting"

    States = merge(local.doc_ingestion_status_updates, {
      SourcesPreProcessing = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.preprocessing.arn
          "Payload.$"  = "$"
        }
        # Trim payload to avoid States.DataLimitExceeded (256KB limit). Only
        # pass the summary fields needed by downstream states. The full
        # per-file issues list is bounded IN THE LAMBDA (issue 104) — the raw
        # Lambda payload is size-checked before this selector runs, so the
        # handler returns a capped preview + an S3 pointer, not the whole array.
        ResultSelector = {
          "status.$"             = "$.Payload.status"
          "files_total.$"        = "$.Payload.files_total"
          "files_preprocessed.$" = "$.Payload.files_preprocessed"
          "files_skipped.$"      = "$.Payload.files_skipped"
          "files_errored.$"      = "$.Payload.files_errored"
          "staging_prefix.$"     = "$.Payload.staging_prefix"
          "issues_preview.$"     = "$.Payload.issues_preview"
          "issues_truncated.$"   = "$.Payload.issues_truncated"
          "issues_s3_key.$"      = "$.Payload.issues_s3_key"
        }
        ResultPath = "$.preprocessResult"
        Retry = [{
          ErrorEquals     = ["Lambda.TooManyRequestsException", "Lambda.SdkClientException"]
          MaxAttempts     = 3
          BackoffRate     = 2
          IntervalSeconds = 2
        }]
        Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "DocUpdateStatusFailed" }]
        Next  = "SourcesSavePreprocessingResults"
      }

      SourcesSavePreprocessingResults = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::dynamodb:updateItem"
        Parameters = {
          TableName = aws_dynamodb_table.sources.name
          Key = {
            PK = { "S.$" = "States.Format('NS#{}', $.namespace_id)" }
            SK = { "S.$" = "States.Format('SRC#{}', $.doc_source_id)" }
          }
          UpdateExpression = "SET #s = :s, #ft = :ft, #fp = :fp, #fs = :fs, #fe = :fe, #pi = :pi, #pik = :pik, #pit = :pit, #u = :u"
          ExpressionAttributeNames = {
            "#s"   = "status"
            "#ft"  = "filesTotal"
            "#fp"  = "filesPreprocessed"
            "#fs"  = "filesSkipped"
            "#fe"  = "filesErrored"
            "#pi"  = "preprocessingIssues"
            "#pik" = "preprocessingIssuesS3Key"
            "#pit" = "preprocessingIssuesTruncated"
            "#u"   = "updatedAt"
          }
          ExpressionAttributeValues = {
            ":s"   = { "S.$" = "$.preprocessResult.status" }
            ":ft"  = { "N.$" = "States.Format('{}', $.preprocessResult.files_total)" }
            ":fp"  = { "N.$" = "States.Format('{}', $.preprocessResult.files_preprocessed)" }
            ":fs"  = { "N.$" = "States.Format('{}', $.preprocessResult.files_skipped)" }
            ":fe"  = { "N.$" = "States.Format('{}', $.preprocessResult.files_errored)" }
            ":pi"  = { "S.$" = "States.JsonToString($.preprocessResult.issues_preview)" }
            ":pik" = { "S.$" = "$.preprocessResult.issues_s3_key" }
            # BOOL.$ substitutes the JSONPath at runtime; a plain "BOOL" would
            # be validated as a boolean literal and reject the JSONPath string
            # (mirrors CDK's booleanFromJsonPath(stringAt(...)) idiom).
            ":pit" = { "BOOL.$" = "$.preprocessResult.issues_truncated" }
            ":u"   = { "S.$" = "$$.State.EnteredTime" }
          }
        }
        ResultPath = null
        Catch      = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "DocUpdateStatusFailed" }]
        Next       = "SourcesPreprocessingSucceeded"
      }

      SourcesPreprocessingSucceeded = {
        Type = "Choice"
        Choices = [{
          Variable     = "$.preprocessResult.status"
          StringEquals = "SCAN_FAILED"
          Next         = "SourcesPreprocessingAllFailed"
        }]
        Default = "SourcesKGBuild"
      }

      SourcesPreprocessingAllFailed = {
        Type  = "Fail"
        Cause = "All files failed preprocessing"
        Error = "PreprocessingError"
      }

      SourcesKGBuild = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::ecs:runTask.sync"
        Parameters = {
          Cluster        = aws_ecs_cluster.kg_build.arn
          TaskDefinition = aws_ecs_task_definition.kg_build.arn
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
              Name = "${var.name_prefix}-sources-doc-kg-build"
              Environment = [
                { Name = "DOC_SOURCE_ID", "Value.$" = "$.doc_source_id" },
                { Name = "NAMESPACE_ID", "Value.$" = "$.namespace_id" },
                # Namespace-language snapshot resolved by the Sources API
                # when the ingestion was triggered (always present via the
                # trigger Lambda).
                { Name = "NAMESPACE_LANGUAGE", "Value.$" = "$.namespace_language" },
                { Name = "TENANT_ID", "Value.$" = "$.tenant_id" },
                { Name = "STAGING_PREFIX", "Value.$" = "$.preprocessResult.staging_prefix" },
                { Name = "EXTRACTION_MODE", "Value.$" = "$.extraction_config.extraction_mode" },
                { Name = "USE_BATCH_INFERENCE", "Value.$" = "$.extraction_config.use_batch_inference" },
                { Name = "ENABLE_VERSIONING", "Value.$" = "$.extraction_config.enable_versioning" },
                { Name = "ENABLE_PROPOSITION_EXTRACTION", "Value.$" = "$.extraction_config.enable_proposition_extraction" },
                { Name = "INFER_ENTITY_CLASSIFICATIONS", "Value.$" = "$.extraction_config.infer_entity_classifications" },
                { Name = "PREFERRED_ENTITY_CLASSIFICATIONS", "Value.$" = "$.extraction_config.preferred_entity_classifications" },
                # Preferred TOPIC vocabulary — the thematic groupings
                # chunks are assigned to (__Topic__ nodes), as distinct
                # from the entity-class list above. Same JSON-string
                # transport for the same reason: a container-override
                # JsonPath cannot carry an array. Empty JSON array "[]"
                # is the default and means "let the model name topics",
                # which is the behaviour of every ingest before this
                # field existed. There is no INFER_TOPICS counterpart —
                # graphrag-toolkit has no topic equivalent of the
                # classification inference pass. The trigger Lambda
                # re-merges EXTRACTION_DEFAULTS into every message
                # before StartExecution so sources created before this
                # field shipped still work.
                { Name = "PREFERRED_TOPICS", "Value.$" = "$.extraction_config.preferred_topics" },
                { Name = "ENABLE_TABLE_EXTRACTION", "Value.$" = "$.extraction_config.enable_table_extraction" },
                { Name = "CHUNK_SIZE", "Value.$" = "$.extraction_config.chunk_size" },
                { Name = "CHUNK_OVERLAP", "Value.$" = "$.extraction_config.chunk_overlap" },
                { Name = "BEDROCK_MODEL_ARN", "Value.$" = "$.extraction_config.bedrock_model_arn" },
                { Name = "DELETE_PREV_VERSIONS", "Value.$" = "$.extraction_config.delete_prev_versions" },
              ]
            }]
          }
        }
        ResultPath = "$.kgBuildResult"
        Retry = [{
          ErrorEquals     = ["ECS.ServiceException", "ECS.AmazonECSException"]
          MaxAttempts     = 3
          BackoffRate     = 2
          IntervalSeconds = 30
        }]
        Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "DocUpdateStatusFailed" }]
        Next  = "DocUpdateStatusCompleted"
      }

      DocIngestionFailed = {
        Type  = "Fail"
        Cause = "Ingestion pipeline failed"
        Error = "IngestionError"
      }
    })
  }
}

resource "aws_sfn_state_machine" "doc_ingestion" {
  name       = "${var.name_prefix}-sources-doc-ingestion-pipeline"
  role_arn   = aws_iam_role.sfn_doc_ingestion.arn
  definition = jsonencode(local.doc_ingestion_definition)

  tracing_configuration {
    enabled = true
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  docDeletion state machine
# ═════════════════════════════════════════════════════════════════════
# Chain: DocCleanupS3 → DocGraphCleanup → DocDeleteDdbRecord
# Any error → DocUpdateStatusDeleteFailed → DocDeletionFailed (Fail).

locals {
  doc_deletion_definition = {
    Comment = "Sources documents deletion pipeline"
    StartAt = "SourcesDocCleanupS3"

    States = merge(
      # Shared error-terminal states are in local.doc_status_update.
      { DocUpdateStatusDeleteFailed = local.doc_status_update["DocUpdateStatusDeleteFailed"] },
      {
        SourcesDocCleanupS3 = {
          Type     = "Task"
          Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
          Parameters = {
            FunctionName = aws_lambda_function.doc_cleanup.arn
            "Payload.$"  = "$"
          }
          ResultSelector = {
            "namespace_id.$"  = "$.Payload.namespace_id"
            "doc_source_id.$" = "$.Payload.doc_source_id"
            "tenant_id.$"     = "$.Payload.tenant_id"
          }
          ResultPath = "$.cleanupResult"
          Retry = [{
            ErrorEquals     = ["Lambda.TooManyRequestsException", "Lambda.SdkClientException"]
            MaxAttempts     = 3
            BackoffRate     = 2
            IntervalSeconds = 2
          }]
          Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "DocUpdateStatusDeleteFailed" }]
          Next  = "SourcesDocGraphCleanup"
        }

        SourcesDocGraphCleanup = {
          Type     = "Task"
          Resource = "arn:${data.aws_partition.current.partition}:states:::ecs:runTask.sync"
          Parameters = {
            Cluster        = aws_ecs_cluster.kg_build.arn
            TaskDefinition = aws_ecs_task_definition.kg_build.arn
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
                Name    = "${var.name_prefix}-sources-doc-kg-build"
                Command = ["python", "-m", "coa_sources.documents.kg_build.graph_cleanup"]
                Environment = [
                  { Name = "DOC_SOURCE_ID", "Value.$" = "$.doc_source_id" },
                  { Name = "NAMESPACE_ID", "Value.$" = "$.namespace_id" },
                  { Name = "TENANT_ID", "Value.$" = "$.tenant_id" },
                  { Name = "NEPTUNE_ENDPOINT", Value = var.neptune_endpoint },
                  { Name = "OPENSEARCH_ENDPOINT", Value = var.opensearch_endpoint },
                ]
              }]
            }
          }
          ResultPath = "$.graphCleanupResult"
          Retry = [{
            ErrorEquals     = ["ECS.ServiceException", "ECS.AmazonECSException"]
            MaxAttempts     = 3
            BackoffRate     = 2
            IntervalSeconds = 30
          }]
          Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "DocUpdateStatusDeleteFailed" }]
          Next  = "SourcesDocDeleteDdbRecord"
        }

        SourcesDocDeleteDdbRecord = {
          Type     = "Task"
          Resource = "arn:${data.aws_partition.current.partition}:states:::dynamodb:deleteItem"
          Parameters = {
            TableName = aws_dynamodb_table.sources.name
            Key = {
              PK = { "S.$" = "States.Format('NS#{}', $.namespace_id)" }
              SK = { "S.$" = "States.Format('SRC#{}', $.doc_source_id)" }
            }
          }
          ResultPath = null
          Catch      = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "DocUpdateStatusDeleteFailed" }]
          End        = true
        }

        DocDeletionFailed = {
          Type  = "Fail"
          Cause = "Deletion pipeline failed"
          Error = "DeletionError"
        }
      },
    )
  }
}

resource "aws_sfn_state_machine" "doc_deletion" {
  name       = "${var.name_prefix}-sources-doc-deletion-pipeline"
  role_arn   = aws_iam_role.sfn_doc_deletion.arn
  definition = jsonencode(local.doc_deletion_definition)

  tracing_configuration {
    enabled = true
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  SQS → docTrigger event source mapping
# ═════════════════════════════════════════════════════════════════════

resource "aws_lambda_event_source_mapping" "doc_ingestion_trigger" {
  event_source_arn                   = aws_sqs_queue.doc_ingestion.arn
  function_name                      = aws_lambda_function.doc_trigger.arn
  batch_size                         = 1
  maximum_batching_window_in_seconds = 0

  scaling_config {
    maximum_concurrency = 5
  }
}
