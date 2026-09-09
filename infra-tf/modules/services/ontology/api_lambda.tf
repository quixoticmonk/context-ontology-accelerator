# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# API proxy Lambda — forwards API Gateway → the ontology-engine ECS
# service over the Cloud Map private DNS FQDN. VPC-attached (Lambda SG)
# so it can reach the container port; the ECS SG ingress rule that admits
# it lives in main.tf.

# ── Execution role ──────────────────────────────────────────────────
resource "aws_iam_role" "api_proxy" {
  name               = "${local.api_fn_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
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

# VPC access (ENI create/describe/delete + CloudWatch Logs).
resource "aws_iam_role_policy_attachment" "api_proxy_vpc" {
  role       = aws_iam_role.api_proxy.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ── Per-function inline permissions (match CDK addToRolePolicy calls) ─
data "aws_iam_policy_document" "api_proxy" {
  # DescribeTable — no resource-level ARN in the CDK (resources: ["*"]).
  statement {
    sid       = "DynamoDbDescribe"
    actions   = ["dynamodb:DescribeTable"]
    resources = ["*"]
  }

  # Neptune read — scoped to the cluster ARN (carries trailing /*).
  statement {
    sid       = "NeptuneRead"
    actions   = ["neptune-db:ReadDataViaQuery", "neptune-db:GetQueryStatus"]
    resources = [var.neptune_cluster_arn]
  }

  # AOSS collection describe — no resource-level ARN in the CDK.
  statement {
    sid       = "AossBatchGet"
    actions   = ["aoss:BatchGetCollection"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "api_proxy" {
  name   = "${local.api_fn_name}-policy"
  policy = data.aws_iam_policy_document.api_proxy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "api_proxy" {
  role       = aws_iam_role.api_proxy.name
  policy_arn = aws_iam_policy.api_proxy.arn
}

# ── Function ────────────────────────────────────────────────────────
resource "aws_lambda_function" "api_proxy" {
  function_name    = local.api_fn_name
  role             = aws_iam_role.api_proxy.arn
  runtime          = "python3.12"
  handler          = "coa_ontology.api_proxy_handler.handler"
  filename         = var.ontology_api_zip_path
  source_code_hash = local.api_zip_hash
  timeout          = 60
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      # FQDN under the Cloud Map namespace — the short name only resolves
      # from inside ECS tasks; Lambda's resolver needs the full name.
      ONTOLOGY_ENGINE_ENDPOINT = local.endpoint
      SOURCES_TABLE            = var.sources_table_name
      NEPTUNE_ENDPOINT         = var.neptune_endpoint
      OPENSEARCH_ENDPOINT      = var.opensearch_endpoint
      ALLOWED_ORIGIN           = var.allowed_origin
    }
  }

  tags = local.tags
}
