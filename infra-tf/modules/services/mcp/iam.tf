# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IAM for the MCP Server AgentCore Runtime.
#
# The CDK bedrockagentcore.Runtime construct auto-creates an execution role
# and attaches inline statements via runtime.addToRolePolicy(...). In the
# Terraform flow that role is explicit: a bedrock-agentcore trust policy,
# plus one aws_iam_policy + aws_iam_role_policy_attachment per concern
# (minimal, least privilege), matching the six statements the CDK attaches.

# ════════════════════════════════════════════════════════════════════
#  Execution role (bedrock-agentcore trust)
# ════════════════════════════════════════════════════════════════════
data "aws_iam_policy_document" "runtime_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "mcp_runtime" {
  name               = "${local.ecr_repo_name}-runtime-role"
  assume_role_policy = data.aws_iam_policy_document.runtime_trust.json

  tags = local.tags
}

# ════════════════════════════════════════════════════════════════════
#  1. ECR auth token (must be unscoped — no resource-level ARN exists)
# ════════════════════════════════════════════════════════════════════
data "aws_iam_policy_document" "ecr_auth_token" {
  statement {
    sid       = "EcrAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecr_auth_token" {
  name   = "${local.ecr_repo_name}-ecr-auth"
  policy = data.aws_iam_policy_document.ecr_auth_token.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ecr_auth_token" {
  role       = aws_iam_role.mcp_runtime.name
  policy_arn = aws_iam_policy.ecr_auth_token.arn
}

# ════════════════════════════════════════════════════════════════════
#  2. ECR image pull (scoped to the module-owned repo)
# ════════════════════════════════════════════════════════════════════
data "aws_iam_policy_document" "ecr_image_pull" {
  statement {
    sid = "EcrImagePull"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = [var.ecr_repository_arn]
  }
}

resource "aws_iam_policy" "ecr_image_pull" {
  name   = "${local.ecr_repo_name}-ecr-pull"
  policy = data.aws_iam_policy_document.ecr_image_pull.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ecr_image_pull" {
  role       = aws_iam_role.mcp_runtime.name
  policy_arn = aws_iam_policy.ecr_image_pull.arn
}

# ════════════════════════════════════════════════════════════════════
#  3. SSM read (resolve CM runtime ARN + other config at runtime)
# ════════════════════════════════════════════════════════════════════
data "aws_iam_policy_document" "ssm_read" {
  statement {
    sid       = "SsmRead"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:${data.aws_partition.current.partition}:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_prefix}/*"]
  }
}

resource "aws_iam_policy" "ssm_read" {
  name   = "${local.ecr_repo_name}-ssm-read"
  policy = data.aws_iam_policy_document.ssm_read.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ssm_read" {
  role       = aws_iam_role.mcp_runtime.name
  policy_arn = aws_iam_policy.ssm_read.arn
}

# ════════════════════════════════════════════════════════════════════
#  4. Invoke Context Manager via the AgentCore invocations API
# ════════════════════════════════════════════════════════════════════
data "aws_iam_policy_document" "invoke_agent_runtime" {
  statement {
    sid = "InvokeAgentRuntime"
    actions = [
      "bedrock-agentcore:InvokeAgentRuntime",
      "bedrock-agentcore:InvokeAgentRuntimeForUser",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:bedrock-agentcore:${var.region}:${data.aws_caller_identity.current.account_id}:runtime/*"]
  }
}

resource "aws_iam_policy" "invoke_agent_runtime" {
  name   = "${local.ecr_repo_name}-invoke-runtime"
  policy = data.aws_iam_policy_document.invoke_agent_runtime.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "invoke_agent_runtime" {
  role       = aws_iam_role.mcp_runtime.name
  policy_arn = aws_iam_policy.invoke_agent_runtime.arn
}

# ════════════════════════════════════════════════════════════════════
#  5. Invoke backend Lambdas directly (discovery tools)
# ════════════════════════════════════════════════════════════════════
data "aws_iam_policy_document" "lambda_invoke_discovery" {
  statement {
    sid       = "LambdaInvokeDiscovery"
    actions   = ["lambda:InvokeFunction"]
    resources = [var.metric_service_lambda_arn, var.ontology_proxy_lambda_arn]
  }
}

resource "aws_iam_policy" "lambda_invoke_discovery" {
  name   = "${local.ecr_repo_name}-lambda-invoke"
  policy = data.aws_iam_policy_document.lambda_invoke_discovery.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "lambda_invoke_discovery" {
  role       = aws_iam_role.mcp_runtime.name
  policy_arn = aws_iam_policy.lambda_invoke_discovery.arn
}

# ════════════════════════════════════════════════════════════════════
#  6. DynamoDB read (grant resolver — roles + resource-role-mappings)
# ════════════════════════════════════════════════════════════════════
data "aws_iam_policy_document" "ddb_read" {
  statement {
    sid = "DdbRead"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:BatchGetItem",
    ]
    resources = [
      var.roles_table_arn,
      var.resource_role_mappings_table_arn,
      "${var.resource_role_mappings_table_arn}/index/*",
    ]
  }
}

resource "aws_iam_policy" "ddb_read" {
  name   = "${local.ecr_repo_name}-ddb-read"
  policy = data.aws_iam_policy_document.ddb_read.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "ddb_read" {
  role       = aws_iam_role.mcp_runtime.name
  policy_arn = aws_iam_policy.ddb_read.arn
}
