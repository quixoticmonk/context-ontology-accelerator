# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Data Layer Stack — Lambda handler for runtime query/retrieval APIs.
#
# Provisions:
#   - Data Layer API Lambda (thin adapter to Context Manager via the
#     serve AgentCore Runtime, plus direct-through proxies to the
#     ontology-engine and metric-service Lambdas)
#   - Per-function IAM execution role (VPC access + scoped invoke grants)
#   - SSM parameter publishing the Lambda ARN for the API module
#
# Mirrors infra/lib/stacks/services/data-layer-stack.ts.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ═════════════════════════════════════════════════════════════════════
#  IAM: execution role
# ═════════════════════════════════════════════════════════════════════

data "aws_iam_policy" "vpc_access" {
  arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api" {
  name               = "${local.fn_api}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "api_vpc" {
  role       = aws_iam_role.api.name
  policy_arn = data.aws_iam_policy.vpc_access.arn
}

# Scoped invoke grants. Two statement groups, both conditional on the
# corresponding var being set:
#   - serve AgentCore Runtime: bedrock-agentcore:InvokeAgentRuntime on
#     the runtime ARN plus a wildcard suffix (the real invocation
#     targets runtime/{id}/runtime-endpoint/{qualifier}).
#   - ontology + metric Lambdas: lambda:InvokeFunction, direct-through.
data "aws_iam_policy_document" "api_policy" {
  # Callers pass "" on the first pass (before 50-agentcore has applied),
  # so guard on non-empty too — an empty ARN produces "/*" which fails
  # IAM's ARN format check.
  dynamic "statement" {
    for_each = var.serve_runtime_arn != null && var.serve_runtime_arn != "" ? [1] : []

    content {
      sid       = "InvokeServeRuntime"
      actions   = ["bedrock-agentcore:InvokeAgentRuntime"]
      resources = [var.serve_runtime_arn, "${var.serve_runtime_arn}/*"]
    }
  }

  dynamic "statement" {
    for_each = length(local.invoke_lambda_arns) > 0 ? [1] : []

    content {
      sid       = "InvokeDiscoveryLambdas"
      actions   = ["lambda:InvokeFunction"]
      resources = local.invoke_lambda_arns
    }
  }
}

# Only create the policy + attachment when at least one invoke target is
# wired (local.api_policy_enabled). With every ARN null the document is
# empty, which is an invalid IAM policy — guard against that.
resource "aws_iam_policy" "api" {
  count = local.api_policy_enabled ? 1 : 0

  name   = "${local.fn_api}-policy"
  policy = data.aws_iam_policy_document.api_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "api" {
  count = local.api_policy_enabled ? 1 : 0

  role       = aws_iam_role.api.name
  policy_arn = aws_iam_policy.api[0].arn
}

# ═════════════════════════════════════════════════════════════════════
#  Data Layer API Lambda
# ═════════════════════════════════════════════════════════════════════

resource "aws_lambda_function" "api" {
  function_name    = local.fn_api
  role             = aws_iam_role.api.arn
  runtime          = "python3.12"
  handler          = "coa_data_layer.handler.handler"
  filename         = var.data_layer_zip_path
  source_code_hash = local.lambda_zip_hash
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = local.api_env
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  SSM: publish Lambda ARN for the API module
# ═════════════════════════════════════════════════════════════════════

resource "aws_ssm_parameter" "api_fn_arn" {
  name  = "${var.ssm_prefix}/data-layer/api-fn-arn"
  type  = "String"
  value = aws_lambda_function.api.arn
  tags  = local.tags
}
