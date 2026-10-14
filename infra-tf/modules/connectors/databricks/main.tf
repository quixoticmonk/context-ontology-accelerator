# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# ── Package the fat jar into a Lambda zip ─────────────────────────────
# Lambda counts a deployment package's EXTRACTED size against its 250MB
# limit and does NOT extract a nested jar — so the fat jar ships inside
# a thin zip at `lib/<jar>`, which puts it on the Java classpath counted
# at its own size. The archive_file data source handles both the staging
# directory and the zip in one step.

resource "local_file" "staging" {
  # Trip-wire: Terraform refuses to create the staging dir implicitly,
  # so we materialise the jar at .build/<function>/lib/<jar> and let
  # archive_file read the directory.
  filename        = "${local.package_root}/lib/${local.jar_file}"
  source          = var.jar_path
  file_permission = "0644"
}

data "archive_file" "package" {
  type        = "zip"
  source_dir  = local.package_root
  output_path = "${path.module}/.build/${local.function_name}.zip"

  depends_on = [local_file.staging]
}

# ── Optional VPC security group ───────────────────────────────────────
# Created only when `vpc_id` is set and `security_group_ids` is null —
# gives the Lambda HTTPS-only egress to the open internet. Set
# `security_group_ids` explicitly to pin a tighter CIDR set.

resource "aws_security_group" "lambda" {
  count = var.vpc_id != null && var.security_group_ids == null ? 1 : 0

  name_prefix = "${local.function_name}-"
  description = "Egress HTTPS-only for the Databricks connector Lambda"
  vpc_id      = var.vpc_id
  tags        = local.base_tags

  egress {
    description      = "HTTPS to Databricks workspace, Secrets Manager, KMS, S3"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

# ── CloudWatch log group ──────────────────────────────────────────────
# Named explicitly rather than letting Lambda generate it, so "check the
# connector's CloudWatch logs" lands in the right place.

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_in_days
  tags              = local.base_tags
}

# ── The Lambda itself ─────────────────────────────────────────────────

resource "aws_lambda_function" "this" {
  function_name    = local.function_name
  role             = aws_iam_role.this.arn
  description      = "Athena Query Federation connector for Databricks SQL Warehouse (${var.config_source} mode)"
  filename         = data.archive_file.package.output_path
  source_code_hash = data.archive_file.package.output_base64sha256
  handler          = "dev.coa.databricks.DatabricksCompositeHandler"
  runtime          = "java21"
  architectures    = ["arm64"]
  timeout          = var.timeout_seconds
  memory_size      = var.memory_size_mb

  dynamic "vpc_config" {
    for_each = var.vpc_id != null ? [1] : []
    content {
      subnet_ids = var.subnet_ids
      security_group_ids = (
        var.security_group_ids != null
        ? var.security_group_ids
        : [aws_security_group.lambda[0].id]
      )
    }
  }

  environment {
    variables = local.environment
  }

  tags = local.base_tags

  # Depend on the log group so CloudWatch doesn't auto-create it with
  # the wrong retention on first invocation.
  depends_on = [aws_cloudwatch_log_group.this]
}
