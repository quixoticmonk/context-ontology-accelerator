# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Shared IAM building blocks + role for API Gateway to invoke the
# authorizer Lambda.

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "lambda_vpc_access" {
  arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ═════════════════════════════════════════════════════════════════════
#  API Gateway → authorizer Lambda invoke role
# ═════════════════════════════════════════════════════════════════════

data "aws_iam_policy_document" "authorizer_invoke_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "authorizer_invoke" {
  name               = "${var.name_prefix}-apigw-authorizer-role"
  assume_role_policy = data.aws_iam_policy_document.authorizer_invoke_trust.json
  tags               = local.tags
}

data "aws_iam_policy_document" "authorizer_invoke" {
  statement {
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.authorizer.arn]
  }
}

resource "aws_iam_role_policy" "authorizer_invoke" {
  name   = "invoke-authorizer"
  role   = aws_iam_role.authorizer_invoke.id
  policy = data.aws_iam_policy_document.authorizer_invoke.json
}
