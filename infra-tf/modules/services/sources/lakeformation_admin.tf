# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Non-destructive registration of `federation_provisioner` as a Lake
# Formation data-lake admin — mirrors the CDK LakeFormationAdmin custom
# resource with a purpose-built Lambda invoked via the new AWS provider
# `action "aws_lambda_invoke"` action_trigger machinery.
#
# Requires Terraform >= 1.14 (action blocks) and AWS provider >= 6.0.
#
# Why a Lambda instead of the native aws_lakeformation_data_lake_settings
# resource? The native resource is REPLACE-only — it blows away every
# admin not in its list. A merge (add ours, preserve everyone else)
# needs read-then-write, which the CDK ships as a custom-resource Lambda
# and this module mirrors.

# ── Execution role ──────────────────────────────────────────────────
data "aws_iam_policy_document" "lakeformation_admin_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lakeformation_admin" {
  name               = "${var.name_prefix}-lakeformation-admin-role"
  assume_role_policy = data.aws_iam_policy_document.lakeformation_admin_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "lakeformation_admin_basic" {
  role       = aws_iam_role.lakeformation_admin.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lakeformation_admin" {
  statement {
    sid = "ManageLakeFormationSettings"
    actions = [
      "lakeformation:GetDataLakeSettings",
      "lakeformation:PutDataLakeSettings",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lakeformation_admin" {
  name   = "${var.name_prefix}-lakeformation-admin-policy"
  policy = data.aws_iam_policy_document.lakeformation_admin.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "lakeformation_admin" {
  role       = aws_iam_role.lakeformation_admin.name
  policy_arn = aws_iam_policy.lakeformation_admin.arn
}

# ── Function ────────────────────────────────────────────────────────
resource "aws_lambda_function" "lakeformation_admin" {
  function_name    = "${var.name_prefix}-lakeformation-admin"
  role             = aws_iam_role.lakeformation_admin.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "index.handler"
  filename         = var.lakeformation_admin_zip_path
  source_code_hash = try(filebase64sha256(var.lakeformation_admin_zip_path), null)
  timeout          = 300
  memory_size      = 256

  tags = local.tags
}

# ── Actions: add on create/update, remove on destroy ────────────────
action "aws_lambda_invoke" "lakeformation_admin_add" {
  config {
    function_name = aws_lambda_function.lakeformation_admin.function_name
    payload = jsonencode({
      action   = "add"
      role_arn = aws_iam_role.federation_provisioner.arn
    })
  }
}

# ── Trigger anchor ──────────────────────────────────────────────────
# terraform_data whose input tracks the target role ARN; changing the
# input drives before_update, triggering re-registration.
# depends_on ensures Lambda + IAM policies are in place before invoke.
#
# Note: TF actions currently support only before/after create+update
# events — no destroy hook. The LF admin registration is left in place
# on stack destroy; it's harmless (the role itself gets deleted anyway)
# and can be manually removed via `aws lakeformation put-data-lake-settings`
# if the admin list needs pruning.
resource "terraform_data" "lakeformation_admin_trigger" {
  input = aws_iam_role.federation_provisioner.arn

  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aws_lambda_invoke.lakeformation_admin_add]
    }
  }

  depends_on = [
    aws_lambda_function.lakeformation_admin,
    aws_iam_role_policy_attachment.lakeformation_admin,
  ]
}
