# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  # Pinned in managed mode because the customer's trust policy names it;
  # customer-deployed connectors leave it to CloudFormation / Terraform
  # to generate a unique name.
  name = local.role_name

  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = local.base_tags
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_access" {
  count = var.vpc_id != null ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ── Spill: read/write own prefix on own bucket, generate data keys on own CMK ─
data "aws_iam_policy_document" "spill" {
  statement {
    sid     = "SpillBucketReadWrite"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "${aws_s3_bucket.spill.arn}/${local.spill_prefix_glob}",
    ]
  }

  statement {
    sid       = "SpillBucketList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.spill.arn]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${local.spill_prefix}/*"]
    }
  }

  statement {
    sid       = "SpillKeyGenerateDataKey"
    actions   = ["kms:GenerateDataKey", "kms:Decrypt", "kms:DescribeKey"]
    resources = [aws_kms_key.spill.arn]
  }
}

resource "aws_iam_policy" "spill" {
  name   = "${local.function_name}-spill"
  policy = data.aws_iam_policy_document.spill.json
  tags   = local.base_tags
}

resource "aws_iam_role_policy_attachment" "spill" {
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.spill.arn
}

# ── Secrets Manager: read the credential secret only ─────────────────────
# `environment` mode: a single hard-coded secret ARN.
# `coa-managed` mode: ALL secrets under the per-source config path (the API
# writes the secretArn into the SSM parameter; the Lambda reads the secret
# the parameter points at — any secret the API chose to publish).
data "aws_iam_policy_document" "secrets_env" {
  count = var.config_source == "environment" && var.credential_secret_arn != null ? 1 : 0

  statement {
    sid       = "ReadCredentialSecret"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [var.credential_secret_arn]
  }

  dynamic "statement" {
    for_each = var.credential_kms_key_arn != null ? [var.credential_kms_key_arn] : []

    content {
      sid       = "DecryptCredentialSecretKey"
      actions   = ["kms:Decrypt", "kms:DescribeKey"]
      resources = [statement.value]
    }
  }
}

resource "aws_iam_policy" "secrets_env" {
  count = var.config_source == "environment" && var.credential_secret_arn != null ? 1 : 0

  name   = "${local.function_name}-secrets"
  policy = data.aws_iam_policy_document.secrets_env[0].json
  tags   = local.base_tags
}

resource "aws_iam_role_policy_attachment" "secrets_env" {
  count = var.config_source == "environment" && var.credential_secret_arn != null ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.secrets_env[0].arn
}

# ── Managed-mode: SSM for per-source config + Secrets Manager wildcard ──
data "aws_iam_policy_document" "managed_config" {
  count = var.config_source == "coa-managed" ? 1 : 0

  statement {
    sid     = "ReadPerSourceConfig"
    actions = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = [
      "arn:${data.aws_partition.current.partition}:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.resource_prefix}/${var.env}/connectors/databricks/sources/*",
    ]
  }

  # Managed mode reads whichever secret the sources API wrote into the SSM
  # parameter. The grant is scoped to Secrets Manager in this account+region,
  # but not pinned to a secret ARN (the API chooses it per source).
  statement {
    sid     = "ReadAnyManagedSecret"
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      "arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:secret:*",
    ]
    # Narrower condition: only secrets the sources API tagged for connector use.
    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/${var.resource_prefix}:connector-credential"
      values   = ["databricks"]
    }
  }
}

resource "aws_iam_policy" "managed_config" {
  count = var.config_source == "coa-managed" ? 1 : 0

  name   = "${local.function_name}-managed-config"
  policy = data.aws_iam_policy_document.managed_config[0].json
  tags   = local.base_tags
}

resource "aws_iam_role_policy_attachment" "managed_config" {
  count = var.config_source == "coa-managed" ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.managed_config[0].arn
}
