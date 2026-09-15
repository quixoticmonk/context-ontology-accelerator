# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Foundation KMS module.
#
# Provisions the single Customer-Managed Key required by CloudWatch
# Logs. AWS does NOT provide an AWS-managed key for log groups (unlike
# S3/DDB/SSM/etc.), so at least one CMK is unavoidable if any log
# group needs at-rest encryption per corp policy 7.1.
#
# Every other service in this deployment uses AWS-managed keys (aws/s3,
# aws/dynamodb, aws/sqs, aws/lambda, aws/ssm, aws/ecr) because the
# workload is NOT classified as Regulated (policy 7.2 does not apply).
# If that classification changes, add per-class CMKs here.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  tags = {
    Component = var.component
  }

  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
}

# ═════════════════════════════════════════════════════════════════════
#  Log-encryption CMK
# ═════════════════════════════════════════════════════════════════════
# Consumers: every aws_cloudwatch_log_group in the deployment.
# Key policy: least-privilege — root for admin operations and the
# regional CloudWatch Logs service principal for encrypt/decrypt via
# the logs.<region>.amazonaws.com service.

data "aws_iam_policy_document" "logs" {
  # Standard root grant (allows IAM policies in this account to
  # further delegate, and enables key deletion via the root user).
  statement {
    sid    = "EnableRootAccountAccess"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  # CloudWatch Logs service principal — required so the service can
  # encrypt log events on ingest and decrypt them on read. Scoped by
  # kms:EncryptionContext to log groups in THIS account + region so
  # the key can't be used to encrypt logs owned by another account.
  statement {
    sid    = "AllowCloudWatchLogsServiceEncryptDecrypt"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]

    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:${local.partition}:logs:${var.region}:${local.account_id}:log-group:*"]
    }
  }
}

resource "aws_kms_key" "logs" {
  description             = "${var.name_prefix} CloudWatch Logs encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.logs.json

  tags = local.tags
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.name_prefix}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

# ═════════════════════════════════════════════════════════════════════
#  SSM handoff for downstream stacks
# ═════════════════════════════════════════════════════════════════════
# Log-consumer modules (sources, ontology, vkg, api) read the key ARN
# from SSM the same way they read every other cross-stack reference.

resource "aws_ssm_parameter" "logs_key_arn" {
  name  = "${var.ssm_prefix}/kms/logs-key-arn"
  type  = "String"
  value = aws_kms_key.logs.arn
  tags  = local.tags
}
