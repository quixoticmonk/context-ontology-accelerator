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
        "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root",
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
  doc_status_update = {
    for entry in [
      { key = "DocUpdateStatusIngesting", status = "SCANNING", include_error = false, next = "SourcesPreProcessing" },
      { key = "DocUpdateStatusCompleted", status = "COMPLETED", include_error = false, next = null },
      { key = "DocUpdateStatusFailed", status = "SCAN_FAILED", include_error = true, next = "DocIngestionFailed" },
      { key = "DocUpdateStatusDeleteFailed", status = "DELETE_FAILED", include_error = true, next = "DocDeletionFailed" },
      ] : entry.key => merge(
      {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::dynamodb:updateItem"
        Parameters = {
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
        }
        ResultPath = null
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
        # Trim payload to avoid States.DataLimitExceeded (256KB).
        ResultSelector = {
          "status.$"             = "$.Payload.status"
          "files_total.$"        = "$.Payload.files_total"
          "files_preprocessed.$" = "$.Payload.files_preprocessed"
          "files_skipped.$"      = "$.Payload.files_skipped"
          "files_errored.$"      = "$.Payload.files_errored"
          "staging_prefix.$"     = "$.Payload.staging_prefix"
          "issues.$"             = "$.Payload.issues"
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
          UpdateExpression = "SET #s = :s, #ft = :ft, #fp = :fp, #fs = :fs, #fe = :fe, #pi = :pi, #u = :u"
          ExpressionAttributeNames = {
            "#s"  = "status"
            "#ft" = "filesTotal"
            "#fp" = "filesPreprocessed"
            "#fs" = "filesSkipped"
            "#fe" = "filesErrored"
            "#pi" = "preprocessingIssues"
            "#u"  = "updatedAt"
          }
          ExpressionAttributeValues = {
            ":s"  = { "S.$" = "$.preprocessResult.status" }
            ":ft" = { "N.$" = "States.Format('{}', $.preprocessResult.files_total)" }
            ":fp" = { "N.$" = "States.Format('{}', $.preprocessResult.files_preprocessed)" }
            ":fs" = { "N.$" = "States.Format('{}', $.preprocessResult.files_skipped)" }
            ":fe" = { "N.$" = "States.Format('{}', $.preprocessResult.files_errored)" }
            ":pi" = { "S.$" = "States.JsonToString($.preprocessResult.issues)" }
            ":u"  = { "S.$" = "$$.State.EnteredTime" }
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
                { Name = "TENANT_ID", "Value.$" = "$.tenant_id" },
                { Name = "STAGING_PREFIX", "Value.$" = "$.preprocessResult.staging_prefix" },
                { Name = "EXTRACTION_MODE", "Value.$" = "$.extraction_config.extraction_mode" },
                { Name = "USE_BATCH_INFERENCE", "Value.$" = "$.extraction_config.use_batch_inference" },
                { Name = "ENABLE_VERSIONING", "Value.$" = "$.extraction_config.enable_versioning" },
                { Name = "ENABLE_PROPOSITION_EXTRACTION", "Value.$" = "$.extraction_config.enable_proposition_extraction" },
                { Name = "INFER_ENTITY_CLASSIFICATIONS", "Value.$" = "$.extraction_config.infer_entity_classifications" },
                { Name = "PREFERRED_ENTITY_CLASSIFICATIONS", "Value.$" = "$.extraction_config.preferred_entity_classifications" },
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
