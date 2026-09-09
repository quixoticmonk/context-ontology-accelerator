# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Namespace deletion Step Functions pipeline.
#
# Pipeline (linear, each step's Catch → MarkFailed → Fail):
#   DeleteSources → DeleteMetrics → DeleteOntology → DeletePlatform → Finalize
#
# Each step gets 3 retries with backoff before the chain proceeds to
# MarkFailed. Matches the CDK NamespaceDeletionPipeline construct.
#
# DeleteOntology is the "must-succeed" step for the AOSS vector index
# (namespace's index lives on a 1000-index-capped collection); the
# retries + catch keep the pipeline recoverable via DELETE_FAILED
# instead of silent orphaning.

locals {
  del_common_env = {
    RESOURCE_PREFIX = "${var.name_prefix}-"
  }
}

# ═════════════════════════════════════════════════════════════════════
#  1. DeleteSources Lambda
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "del_sources" {
  name               = "${local.fn_del_sources}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "del_sources_vpc" {
  role       = aws_iam_role.del_sources.name
  policy_arn = data.aws_iam_policy.vpc_access.arn
}

data "aws_iam_policy_document" "del_sources_policy" {
  # Invoke sources-api Lambda by convention-derived function ARN
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = ["arn:${data.aws_partition.current.partition}:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${local.fn_sources_api}"]
  }

  # AOSS APIAccessAll (needed when GraphRAG index cleanup is enabled).
  # aoss:DescribeIndex + aoss:DeleteIndex are enforced by the data-access
  # policy below AND require aoss:APIAccessAll on the collection ARN.
  dynamic "statement" {
    for_each = local.aoss_deletion_enabled ? [1] : []
    content {
      actions   = ["aoss:APIAccessAll"]
      resources = ["arn:${data.aws_partition.current.partition}:aoss:${var.region}:${data.aws_caller_identity.current.account_id}:collection/*"]
    }
  }
}

resource "aws_iam_policy" "del_sources" {
  name   = "${local.fn_del_sources}-policy"
  policy = data.aws_iam_policy_document.del_sources_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "del_sources" {
  role       = aws_iam_role.del_sources.name
  policy_arn = aws_iam_policy.del_sources.arn
}

resource "aws_lambda_function" "del_sources" {
  function_name    = local.fn_del_sources
  role             = aws_iam_role.del_sources.arn
  runtime          = "python3.12"
  handler          = "coa_control_plane.namespace.deletion_pipeline.delete_sources.handler"
  filename         = var.control_plane_zip_path
  source_code_hash = local.lambda_zip_hash
  timeout          = 600
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = merge(
      local.del_common_env,
      { SOURCES_API_FN_NAME = local.fn_sources_api },
      local.aoss_deletion_enabled ? { OSS_ENDPOINT = var.opensearch_endpoint } : {},
    )
  }

  tags = local.tags
}

# AOSS data-access policy: authorize del_sources role to drop the
# namespace's GraphRAG doc-KG indexes (chunk_*, topic_*, statement_*).
# Scoped to those prefixes deliberately — NOT index/<collection>/* —
# so a bug here cannot touch ontology or metric indexes in the same
# collection. Matches CDK NsDeletionGraphragIndexAccess exactly.
resource "aws_opensearchserverless_access_policy" "del_sources_graphrag" {
  count = local.aoss_deletion_enabled ? 1 : 0

  name        = "${var.name_prefix}-ns-del-graphrag"
  type        = "data"
  description = "Allows namespace deletion to drop GraphRAG doc-KG indexes"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index"
          Resource = [
            "index/${var.opensearch_collection_name}/chunk_*",
            "index/${var.opensearch_collection_name}/topic_*",
            "index/${var.opensearch_collection_name}/statement_*",
          ]
          Permission = ["aoss:DescribeIndex", "aoss:DeleteIndex"]
        }
      ]
      Principal = [aws_iam_role.del_sources.arn]
    }
  ])
}

# ═════════════════════════════════════════════════════════════════════
#  2. DeleteMetrics Lambda
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "del_metrics" {
  name               = "${local.fn_del_metrics}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "del_metrics_vpc" {
  role       = aws_iam_role.del_metrics.name
  policy_arn = data.aws_iam_policy.vpc_access.arn
}

data "aws_iam_policy_document" "del_metrics_policy" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = ["arn:${data.aws_partition.current.partition}:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${local.fn_metric_api}"]
  }
}

resource "aws_iam_policy" "del_metrics" {
  name   = "${local.fn_del_metrics}-policy"
  policy = data.aws_iam_policy_document.del_metrics_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "del_metrics" {
  role       = aws_iam_role.del_metrics.name
  policy_arn = aws_iam_policy.del_metrics.arn
}

resource "aws_lambda_function" "del_metrics" {
  function_name    = local.fn_del_metrics
  role             = aws_iam_role.del_metrics.arn
  runtime          = "python3.12"
  handler          = "coa_control_plane.namespace.deletion_pipeline.delete_metrics.handler"
  filename         = var.control_plane_zip_path
  source_code_hash = local.lambda_zip_hash
  timeout          = 300
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = merge(
      local.del_common_env,
      { METRIC_API_FN_NAME = local.fn_metric_api },
    )
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  3. DeleteOntology Lambda
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "del_ontology" {
  name               = "${local.fn_del_ontology}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "del_ontology_vpc" {
  role       = aws_iam_role.del_ontology.name
  policy_arn = data.aws_iam_policy.vpc_access.arn
}

data "aws_iam_policy_document" "del_ontology_policy" {
  dynamic "statement" {
    for_each = var.ontology_bucket_name != null ? [1] : []
    content {
      actions = ["s3:DeleteObject", "s3:ListBucket"]
      resources = [
        "arn:${data.aws_partition.current.partition}:s3:::${var.ontology_bucket_name}",
        "arn:${data.aws_partition.current.partition}:s3:::${var.ontology_bucket_name}/ontologies/*",
      ]
    }
  }
}

resource "aws_iam_policy" "del_ontology" {
  name   = "${local.fn_del_ontology}-policy"
  policy = data.aws_iam_policy_document.del_ontology_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "del_ontology" {
  role       = aws_iam_role.del_ontology.name
  policy_arn = aws_iam_policy.del_ontology.arn
}

resource "aws_lambda_function" "del_ontology" {
  function_name    = local.fn_del_ontology
  role             = aws_iam_role.del_ontology.arn
  runtime          = "python3.12"
  handler          = "coa_control_plane.namespace.deletion_pipeline.delete_ontology.handler"
  filename         = var.control_plane_zip_path
  source_code_hash = local.lambda_zip_hash
  timeout          = 240
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = merge(
      local.del_common_env,
      var.ontology_bucket_name != null ? { ONTOLOGY_BUCKET = var.ontology_bucket_name } : {},
      var.ontology_engine_endpoint != null ? { ONTOLOGY_ENGINE_ENDPOINT = var.ontology_engine_endpoint } : {},
    )
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  4. DeletePlatform Lambda (VKG, Athena, DataZone, role mappings, roles)
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "del_platform" {
  name               = "${local.fn_del_platform}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "del_platform_vpc" {
  role       = aws_iam_role.del_platform.name
  policy_arn = data.aws_iam_policy.vpc_access.arn
}

data "aws_iam_policy_document" "del_platform_policy" {
  # Full R/W on the two authnz tables
  statement {
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan",
      "dynamodb:BatchWriteItem", "dynamodb:BatchGetItem",
    ]
    resources = [
      var.resource_role_mappings_table_arn,
      "${var.resource_role_mappings_table_arn}/index/*",
      var.roles_table_arn,
      "${var.roles_table_arn}/index/*",
    ]
  }

  statement {
    actions   = ["athena:DeleteWorkGroup", "athena:GetWorkGroup"]
    resources = ["arn:${data.aws_partition.current.partition}:athena:${var.region}:${data.aws_caller_identity.current.account_id}:workgroup/*"]
  }

  # Assume namespace_api role for datazone:DeleteProject (project-owner
  # authorization — see the trust-policy comment on aws_iam_role.namespace_api).
  statement {
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.namespace_api.arn]
  }

  # VKG per-namespace ECS service teardown
  dynamic "statement" {
    for_each = var.vkg_cluster_arn != null ? [1] : []
    content {
      actions   = ["ecs:DeleteService", "ecs:DescribeServices"]
      resources = ["*"]

      condition {
        test     = "ArnLike"
        variable = "ecs:cluster"
        values   = [var.vkg_cluster_arn]
      }
    }
  }

  # Cloud Map service discovery cleanup
  dynamic "statement" {
    for_each = var.cloud_map_namespace_id != null ? [1] : []
    content {
      actions = [
        "servicediscovery:DeleteService",
        "servicediscovery:ListServices",
        "servicediscovery:ListInstances",
        "servicediscovery:DeregisterInstance",
      ]
      resources = ["*"]
    }
  }
}

resource "aws_iam_policy" "del_platform" {
  name   = "${local.fn_del_platform}-policy"
  policy = data.aws_iam_policy_document.del_platform_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "del_platform" {
  role       = aws_iam_role.del_platform.name
  policy_arn = aws_iam_policy.del_platform.arn
}

resource "aws_lambda_function" "del_platform" {
  function_name    = local.fn_del_platform
  role             = aws_iam_role.del_platform.arn
  runtime          = "python3.12"
  handler          = "coa_control_plane.namespace.deletion_pipeline.delete_platform.handler"
  filename         = var.control_plane_zip_path
  source_code_hash = local.lambda_zip_hash
  timeout          = 120
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = merge(
      local.del_common_env,
      {
        RESOURCE_ROLE_MAPPINGS_TABLE = var.resource_role_mappings_table_name
        ROLES_TABLE                  = var.roles_table_name
        DATAZONE_DOMAIN_ID           = aws_datazone_domain.this.id
        PROJECT_ACCESS_ROLE_ARN      = aws_iam_role.namespace_api.arn
      },
      var.vkg_cluster_arn != null ? { VKG_CLUSTER_ARN = var.vkg_cluster_arn } : {},
      var.cloud_map_namespace_id != null ? { CLOUD_MAP_NAMESPACE_ID = var.cloud_map_namespace_id } : {},
    )
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  5. Finalize Lambda (namespace record + name reservation delete)
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "del_finalize" {
  name               = "${local.fn_del_finalize}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "del_finalize_vpc" {
  role       = aws_iam_role.del_finalize.name
  policy_arn = data.aws_iam_policy.vpc_access.arn
}

data "aws_iam_policy_document" "del_finalize_policy" {
  statement {
    actions   = ["dynamodb:TransactWriteItems", "dynamodb:DeleteItem"]
    resources = [aws_dynamodb_table.namespaces.arn]
  }
}

resource "aws_iam_policy" "del_finalize" {
  name   = "${local.fn_del_finalize}-policy"
  policy = data.aws_iam_policy_document.del_finalize_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "del_finalize" {
  role       = aws_iam_role.del_finalize.name
  policy_arn = aws_iam_policy.del_finalize.arn
}

resource "aws_lambda_function" "del_finalize" {
  function_name    = local.fn_del_finalize
  role             = aws_iam_role.del_finalize.arn
  runtime          = "python3.12"
  handler          = "coa_control_plane.namespace.deletion_pipeline.finalize.handler"
  filename         = var.control_plane_zip_path
  source_code_hash = local.lambda_zip_hash
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = merge(
      local.del_common_env,
      { NAMESPACES_TABLE = aws_dynamodb_table.namespaces.name },
    )
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  6. MarkFailed Lambda (terminal error path)
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "del_mark_failed" {
  name               = "${local.fn_del_mark_failed}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "del_mark_failed_vpc" {
  role       = aws_iam_role.del_mark_failed.name
  policy_arn = data.aws_iam_policy.vpc_access.arn
}

data "aws_iam_policy_document" "del_mark_failed_policy" {
  statement {
    actions   = ["dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:GetItem"]
    resources = [aws_dynamodb_table.namespaces.arn]
  }
}

resource "aws_iam_policy" "del_mark_failed" {
  name   = "${local.fn_del_mark_failed}-policy"
  policy = data.aws_iam_policy_document.del_mark_failed_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "del_mark_failed" {
  role       = aws_iam_role.del_mark_failed.name
  policy_arn = aws_iam_policy.del_mark_failed.arn
}

resource "aws_lambda_function" "del_mark_failed" {
  function_name    = local.fn_del_mark_failed
  role             = aws_iam_role.del_mark_failed.arn
  runtime          = "python3.12"
  handler          = "coa_control_plane.namespace.deletion_pipeline.mark_failed.handler"
  filename         = var.control_plane_zip_path
  source_code_hash = local.lambda_zip_hash
  timeout          = 10
  memory_size      = 128

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = merge(
      local.del_common_env,
      { NAMESPACES_TABLE = aws_dynamodb_table.namespaces.name },
    )
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  Step Functions state machine
# ═════════════════════════════════════════════════════════════════════
# Sequential pipeline with per-step retries + catch → MarkFailed → Fail.
# Retry policy per step: max 3 attempts, backoff 2x, initial 5s.
# MarkFailed has no retries — it's the terminal error path.

data "aws_iam_policy_document" "sfn_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["states.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "sfn_policy" {
  statement {
    actions = ["lambda:InvokeFunction"]
    resources = [
      aws_lambda_function.del_sources.arn,
      aws_lambda_function.del_metrics.arn,
      aws_lambda_function.del_ontology.arn,
      aws_lambda_function.del_platform.arn,
      aws_lambda_function.del_finalize.arn,
      aws_lambda_function.del_mark_failed.arn,
      "${aws_lambda_function.del_sources.arn}:*",
      "${aws_lambda_function.del_metrics.arn}:*",
      "${aws_lambda_function.del_ontology.arn}:*",
      "${aws_lambda_function.del_platform.arn}:*",
      "${aws_lambda_function.del_finalize.arn}:*",
      "${aws_lambda_function.del_mark_failed.arn}:*",
    ]
  }

  # X-Ray tracing (tracing_enabled = true below)
  statement {
    actions = [
      "xray:PutTraceSegments",
      "xray:PutTelemetryRecords",
      "xray:GetSamplingRules",
      "xray:GetSamplingTargets",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "sfn" {
  name               = "${var.name_prefix}-namespace-deletion-sfn"
  assume_role_policy = data.aws_iam_policy_document.sfn_trust.json
  tags               = local.tags
}

resource "aws_iam_policy" "sfn" {
  name   = "${var.name_prefix}-namespace-deletion-sfn-policy"
  policy = data.aws_iam_policy_document.sfn_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "sfn" {
  role       = aws_iam_role.sfn.name
  policy_arn = aws_iam_policy.sfn.arn
}

locals {
  # Shared retry config — matches CDK's addRetry defaults.
  sfn_retry = [{
    ErrorEquals     = ["States.ALL"]
    MaxAttempts     = 3
    BackoffRate     = 2
    IntervalSeconds = 5
  }]

  namespace_deletion_definition = {
    Comment = "Cascading namespace cleanup pipeline"
    StartAt = "DeleteSources"

    States = {
      DeleteSources = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.del_sources.arn
          "Payload.$"  = "$"
        }
        ResultSelector = { "sourcesResult.$" = "$.Payload" }
        ResultPath     = "$.sourcesResult"
        Retry          = local.sfn_retry
        Catch          = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "MarkFailed" }]
        Next           = "DeleteMetrics"
      }

      DeleteMetrics = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.del_metrics.arn
          "Payload.$"  = "$"
        }
        ResultSelector = { "metricsResult.$" = "$.Payload" }
        ResultPath     = "$.metricsResult"
        Retry          = local.sfn_retry
        Catch          = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "MarkFailed" }]
        Next           = "DeleteOntology"
      }

      DeleteOntology = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.del_ontology.arn
          "Payload.$"  = "$"
        }
        ResultSelector = { "ontologyResult.$" = "$.Payload" }
        ResultPath     = "$.ontologyResult"
        Retry          = local.sfn_retry
        Catch          = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "MarkFailed" }]
        Next           = "DeletePlatform"
      }

      DeletePlatform = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.del_platform.arn
          "Payload.$"  = "$"
        }
        ResultSelector = { "platformResult.$" = "$.Payload" }
        ResultPath     = "$.platformResult"
        Retry          = local.sfn_retry
        Catch          = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "MarkFailed" }]
        Next           = "Finalize"
      }

      Finalize = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.del_finalize.arn
          "Payload.$"  = "$"
        }
        ResultSelector = { "finalizeResult.$" = "$.Payload" }
        ResultPath     = "$.finalizeResult"
        Retry          = local.sfn_retry
        Catch          = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "MarkFailed" }]
        End            = true
      }

      MarkFailed = {
        Type     = "Task"
        Resource = "arn:${data.aws_partition.current.partition}:states:::lambda:invoke"
        Parameters = {
          FunctionName = aws_lambda_function.del_mark_failed.arn
          "Payload.$"  = "$"
        }
        ResultSelector = { "markFailedResult.$" = "$.Payload" }
        ResultPath     = "$.markFailedResult"
        Next           = "DeletionFailed"
      }

      DeletionFailed = {
        Type  = "Fail"
        Cause = "Namespace deletion failed"
        Error = "NamespaceDeletionError"
      }
    }
  }
}

resource "aws_sfn_state_machine" "namespace_deletion" {
  name       = "${var.name_prefix}-namespace-deletion-pipeline"
  role_arn   = aws_iam_role.sfn.arn
  definition = jsonencode(local.namespace_deletion_definition)

  tracing_configuration {
    enabled = true
  }

  tags = local.tags
}
