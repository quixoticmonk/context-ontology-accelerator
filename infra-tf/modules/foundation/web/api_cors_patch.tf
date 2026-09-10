# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# API Gateway Gateway-Response CORS origin + stage redeployment.
#
# The API module in the same stack creates DEFAULT_4XX/DEFAULT_5XX
# gateway responses with Access-Control-Allow-Origin set to "*" (its
# `allowed_origin` var doesn't yet know the CloudFront domain — that's
# in this module). Browsers refuse "*" for credentialed requests, so
# after the CF distribution is up we patch the two gateway responses
# to the specific origin, then force a stage redeployment so the patch
# goes live.
#
# Mirrors CDK `UpdateApiCors4XX`+`UpdateApiCors5XX`+`RedeployApi` custom
# resources (`infra/lib/stacks/services/web-stack.ts:317-386`).

locals {
  api_cors_patch_enabled = (
    var.api_rest_api_id != "" &&
    var.api_stage_name != "" &&
    var.api_cors_patch_zip_path != ""
  )
}

data "aws_iam_policy_document" "api_cors_patch_trust" {
  count = local.api_cors_patch_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api_cors_patch" {
  count              = local.api_cors_patch_enabled ? 1 : 0
  name               = "${var.name_prefix}-api-cors-patch-role"
  assume_role_policy = data.aws_iam_policy_document.api_cors_patch_trust[0].json
  tags               = { Component = var.component }
}

resource "aws_iam_role_policy_attachment" "api_cors_patch_basic" {
  count      = local.api_cors_patch_enabled ? 1 : 0
  role       = aws_iam_role.api_cors_patch[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "api_cors_patch" {
  count = local.api_cors_patch_enabled ? 1 : 0

  statement {
    sid = "PatchGatewayResponsesAndRedeploy"
    actions = [
      "apigateway:PATCH",
      "apigateway:POST",
      "apigateway:GET",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:apigateway:${local.region}::/restapis/${var.api_rest_api_id}/gatewayresponses/*",
      "arn:${data.aws_partition.current.partition}:apigateway:${local.region}::/restapis/${var.api_rest_api_id}/deployments",
      "arn:${data.aws_partition.current.partition}:apigateway:${local.region}::/restapis/${var.api_rest_api_id}/stages/${var.api_stage_name}",
    ]
  }
}

resource "aws_iam_policy" "api_cors_patch" {
  count  = local.api_cors_patch_enabled ? 1 : 0
  name   = "${var.name_prefix}-api-cors-patch-policy"
  policy = data.aws_iam_policy_document.api_cors_patch[0].json
  tags   = { Component = var.component }
}

resource "aws_iam_role_policy_attachment" "api_cors_patch" {
  count      = local.api_cors_patch_enabled ? 1 : 0
  role       = aws_iam_role.api_cors_patch[0].name
  policy_arn = aws_iam_policy.api_cors_patch[0].arn
}

resource "aws_lambda_function" "api_cors_patch" {
  count            = local.api_cors_patch_enabled ? 1 : 0
  function_name    = "${var.name_prefix}-api-cors-patch"
  role             = aws_iam_role.api_cors_patch[0].arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "index.handler"
  filename         = var.api_cors_patch_zip_path
  source_code_hash = try(filebase64sha256(var.api_cors_patch_zip_path), null)
  timeout          = 60
  memory_size      = 256

  tags = { Component = var.component }
}

action "aws_lambda_invoke" "api_cors_patch" {
  count = local.api_cors_patch_enabled ? 1 : 0

  config {
    function_name = aws_lambda_function.api_cors_patch[0].function_name
    payload = jsonencode({
      rest_api_id = var.api_rest_api_id
      stage_name  = var.api_stage_name
      origin      = local.site_url
    })
  }
}

resource "terraform_data" "api_cors_patch_trigger" {
  count = local.api_cors_patch_enabled ? 1 : 0

  # Re-fire whenever the CF domain OR the target origin changes.
  input = "${aws_cloudfront_distribution.this.domain_name}::${local.site_url}::${var.api_rest_api_id}::${var.api_stage_name}"

  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aws_lambda_invoke.api_cors_patch[0]]
    }
  }

  depends_on = [
    aws_lambda_function.api_cors_patch,
    aws_iam_role_policy_attachment.api_cors_patch,
  ]
}
