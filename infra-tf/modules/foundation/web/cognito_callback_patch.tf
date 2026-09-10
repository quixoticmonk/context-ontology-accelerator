# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Register the CloudFront callback + logout URLs on the Cognito user
# pool client created by stack 10-foundation.
#
# Why not do this inline in stack 10? The CloudFront distribution's
# domain name isn't known until stack 60 applies. The CDK ships this as
# a custom-resource Lambda; this module mirrors that with a purpose-
# built Lambda invoked via the AWS provider's `aws_lambda_invoke`
# action, triggered by a `terraform_data` whose input is the CF domain.

# Gate the whole thing on Cognito being enabled AND all inputs provided.
data "aws_partition" "current" {}

locals {
  cognito_patch_enabled = (
    var.user_pool_id != "" &&
    var.userpool_client_id != "" &&
    var.cognito_callback_patch_zip_path != ""
  )
}

data "aws_iam_policy_document" "cognito_patch_trust" {
  count = local.cognito_patch_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cognito_patch" {
  count              = local.cognito_patch_enabled ? 1 : 0
  name               = "${var.name_prefix}-cognito-callback-patch-role"
  assume_role_policy = data.aws_iam_policy_document.cognito_patch_trust[0].json
  tags               = { Component = var.component }
}

resource "aws_iam_role_policy_attachment" "cognito_patch_basic" {
  count      = local.cognito_patch_enabled ? 1 : 0
  role       = aws_iam_role.cognito_patch[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "cognito_patch" {
  count = local.cognito_patch_enabled ? 1 : 0

  statement {
    sid = "PatchUserPoolClient"
    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "cognito-idp:UpdateUserPoolClient",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:cognito-idp:${local.region}:${local.account_id}:userpool/${var.user_pool_id}"]
  }
}

resource "aws_iam_policy" "cognito_patch" {
  count  = local.cognito_patch_enabled ? 1 : 0
  name   = "${var.name_prefix}-cognito-callback-patch-policy"
  policy = data.aws_iam_policy_document.cognito_patch[0].json
  tags   = { Component = var.component }
}

resource "aws_iam_role_policy_attachment" "cognito_patch" {
  count      = local.cognito_patch_enabled ? 1 : 0
  role       = aws_iam_role.cognito_patch[0].name
  policy_arn = aws_iam_policy.cognito_patch[0].arn
}

resource "aws_lambda_function" "cognito_patch" {
  count            = local.cognito_patch_enabled ? 1 : 0
  function_name    = "${var.name_prefix}-cognito-callback-patch"
  role             = aws_iam_role.cognito_patch[0].arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "index.handler"
  filename         = var.cognito_callback_patch_zip_path
  source_code_hash = try(filebase64sha256(var.cognito_callback_patch_zip_path), null)
  timeout          = 60
  memory_size      = 256

  tags = { Component = var.component }
}

# Payload for the action — CF domain resolved from the distribution.
locals {
  cognito_patch_callback_url = local.cognito_patch_enabled ? "${local.site_url}/authenticate/" : ""
  cognito_patch_logout_url   = local.cognito_patch_enabled ? "${local.site_url}/" : ""
}

action "aws_lambda_invoke" "cognito_callback_patch" {
  count = local.cognito_patch_enabled ? 1 : 0

  config {
    function_name = aws_lambda_function.cognito_patch[0].function_name
    payload = jsonencode({
      user_pool_id = var.user_pool_id
      client_id    = var.userpool_client_id
      callback_url = local.cognito_patch_callback_url
      logout_url   = local.cognito_patch_logout_url
    })
  }
}

# Trigger anchor: input is the CF domain + callback URL. Any change
# re-fires the action to re-register the (possibly new) URL. Depends
# on the distribution being created + the Lambda + IAM ready.
resource "terraform_data" "cognito_callback_patch_trigger" {
  count = local.cognito_patch_enabled ? 1 : 0

  input = "${aws_cloudfront_distribution.this.domain_name}::${local.cognito_patch_callback_url}"

  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aws_lambda_invoke.cognito_callback_patch[0]]
    }
  }

  depends_on = [
    aws_lambda_function.cognito_patch,
    aws_iam_role_policy_attachment.cognito_patch,
  ]
}
