# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# ─────────────────────────────────────────────────────────────────────────────
# ENI warmer — pre-creates Lambda Hyperplane ENIs for every (subnet, SG-set)
# combination the platform uses.
#
# Lambda creates one shared Hyperplane ENI per unique (subnet, SG-set)
# combination, and the first function to request a new combination waits
# ~228 s for EC2 to attach the ENI. Every later function on the same combo
# creates in ~10 s. This module holds one never-invoked Lambda per combo so
# the wait happens here (in parallel with the storage module) instead of
# serially inside every service module on the critical path.
#
# The functions are never invoked. The handler is defensive — if something
# triggers the function by accident, it raises so the fault is loud.
#
# Keep the combos in step with the real VPC Lambdas on the platform: a
# function whose (subnet, SG-set) matches none of these pays the full
# ~228 s wait again. Current combos — Lambda, LambdaOcsp, Ecs, Authorizer —
# cover every VPC Lambda in `infra-tf/modules/services/`.
# ─────────────────────────────────────────────────────────────────────────────

locals {
  combos = {
    lambda = {
      description     = "shared Lambda SG"
      security_groups = [var.lambda_security_group_id]
    }
    lambdaocsp = {
      description     = "shared Lambda SG + Snowflake OCSP SG"
      security_groups = [var.lambda_security_group_id, var.discovery_ocsp_security_group_id]
    }
    ecs = {
      description     = "ECS task SG (vkg reload)"
      security_groups = [var.ecs_security_group_id]
    }
    authorizer = {
      description     = "API authorizer SG"
      security_groups = [var.authorizer_security_group_id]
    }
  }
}

# ── Inline handler ───────────────────────────────────────────────────────────
# Lambda creates the Hyperplane ENI when the function is created, not when it
# is invoked, so the handler only has to refuse to run.
resource "local_file" "handler" {
  filename        = "${path.module}/.build/index.py"
  file_permission = "0644"
  content         = <<-PY
    # Never invoked. Lambda creates its Hyperplane ENI when the function is
    # created, which is the only reason this exists. If something invokes it,
    # fail loud so the fault is traceable instead of silently returning.
    def handler(event, context):
        raise RuntimeError(
            "eni-warm: holds a VPC network interface for this security-group "
            "set; not meant to be invoked"
        )
  PY
}

data "archive_file" "package" {
  type        = "zip"
  source_file = local_file.handler.filename
  output_path = "${path.module}/.build/package.zip"
}

# ── Shared execution role ────────────────────────────────────────────────────
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "exec" {
  name               = "${var.name_prefix}-eni-warm-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

# AWSLambdaVPCAccessExecutionRole grants the ENI create/attach/detach
# permissions Lambda needs on behalf of the function.
resource "aws_iam_role_policy_attachment" "vpc" {
  role       = aws_iam_role.exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ── Per-combo CloudWatch Logs ────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "warm" {
  for_each          = local.combos
  name              = "/aws/lambda/${var.name_prefix}-eni-warm-${each.key}"
  retention_in_days = 7
  kms_key_id        = var.logs_kms_key_arn
  tags              = var.tags
}

# ── Per-combo warmer Lambda ──────────────────────────────────────────────────
resource "aws_lambda_function" "warm" {
  # checkov:skip=CKV_AWS_116:Never-invoked function; DLQ would never receive an event. Any invocation is a misconfiguration that must surface, not be silently queued.
  # checkov:skip=CKV_AWS_173:No environment variables set on this function; nothing to encrypt.
  # checkov:skip=CKV_AWS_117:VPC placement is the entire point — this function exists only to create a Hyperplane ENI for a specific (subnet, SG-set) combination.
  # checkov:skip=CKV_AWS_272:Code signing is not configured on any Lambda in this fork; adopting it here would be an orthogonal, repo-wide change.
  # checkov:skip=CKV_AWS_115:No concurrency limit — the function is never invoked.
  for_each = local.combos

  function_name = "${var.name_prefix}-eni-warm-${each.key}"
  description   = "Never invoked: holds a Hyperplane ENI for the ${each.value.description}"
  role          = aws_iam_role.exec.arn
  runtime       = "python3.12"
  handler       = "index.handler"
  architectures = ["x86_64"]

  filename         = data.archive_file.package.output_path
  source_code_hash = data.archive_file.package.output_base64sha256

  memory_size = 128
  timeout     = 3

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = each.value.security_groups
  }

  tracing_config {
    mode = "PassThrough"
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.vpc,
    aws_cloudwatch_log_group.warm,
  ]
}
