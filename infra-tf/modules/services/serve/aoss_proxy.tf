# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# AOSS search proxy Lambda — routes vector search through a Lambda
# whose IAM role IS recognized by AOSS. Removed when AgentCore
# containers can access AOSS data plane directly.

# ── Role ────────────────────────────────────────────────────────────
data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "aoss_proxy" {
  name               = "${local.aoss_proxy_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "aoss_proxy_vpc" {
  role       = aws_iam_role.aoss_proxy.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "aoss_proxy" {
  statement {
    sid       = "AossApiAccess"
    actions   = ["aoss:APIAccessAll"]
    resources = [var.opensearch_collection_arn]
  }
}

resource "aws_iam_policy" "aoss_proxy" {
  name   = "${local.aoss_proxy_name}-policy"
  policy = data.aws_iam_policy_document.aoss_proxy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "aoss_proxy" {
  role       = aws_iam_role.aoss_proxy.name
  policy_arn = aws_iam_policy.aoss_proxy.arn
}

# ── Lambda ──────────────────────────────────────────────────────────
resource "aws_lambda_function" "aoss_proxy" {
  function_name    = local.aoss_proxy_name
  role             = aws_iam_role.aoss_proxy.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "index.handler"
  filename         = var.aoss_proxy_zip_path
  source_code_hash = local.aoss_proxy_zip_hash
  timeout          = 30
  memory_size      = 512

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      OPENSEARCH_ENDPOINT = var.opensearch_endpoint
    }
  }

  tags = local.tags
}

# ── AOSS data-access policy for the proxy role ──────────────────────
resource "aws_opensearchserverless_access_policy" "aoss_proxy" {
  name        = "${var.name_prefix}-proxy-read-only"
  type        = "data"
  description = "Read-only data access for AOSS search proxy Lambda"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index"
          Resource     = ["index/${var.opensearch_collection_name}/*"]
          Permission   = ["aoss:DescribeIndex", "aoss:ReadDocument"]
        },
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.opensearch_collection_name}"]
          Permission   = ["aoss:DescribeCollectionItems"]
        },
      ]
      Principal = [aws_iam_role.aoss_proxy.arn]
    }
  ])
}
