# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Spill: KMS key + S3 bucket.
#
# SSE-KMS on the spill bucket is REQUIRED — the invoke contract gates
# `kms:Decrypt` on the `coa:connector-spill` tag, so a bucket with
# SSE-S3 or no encryption would skip the check and spill authorization
# would rest on the key prefix alone (the LLD §5.1 rules this out).

resource "aws_kms_key" "spill" {
  description             = "Spill encryption for the databricks COA connector"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  # Prod convention: retain on destroy so an in-flight investigation of
  # a hung query doesn't lose evidence. Default policy destroys.
  tags = local.spill_kms_tags

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_kms_alias" "spill" {
  name          = "alias/${local.function_name}-spill"
  target_key_id = aws_kms_key.spill.id
}

resource "aws_s3_bucket" "spill" {
  bucket        = local.spill_bucket_name
  force_destroy = !var.retain_spill_on_destroy
  tags          = local.base_tags
}

resource "aws_s3_bucket_public_access_block" "spill" {
  bucket                  = aws_s3_bucket.spill.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "spill" {
  bucket = aws_s3_bucket.spill.id

  rule {
    bucket_key_enabled = true # without this a CMK turns every spilled block into billable KMS traffic
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.spill.arn
    }
  }
}

resource "aws_s3_bucket_versioning" "spill" {
  bucket = aws_s3_bucket.spill.id

  versioning_configuration {
    status = "Disabled" # spill is scratch; a version from an old query is noise
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "spill" {
  bucket = aws_s3_bucket.spill.id

  rule {
    id     = "expire-spill"
    status = "Enabled"

    filter {}

    expiration {
      days = 1 # anything older than its query is garbage
    }
  }
}

# TLS-only (defense in depth; SSE-KMS already covers at-rest).
data "aws_iam_policy_document" "spill_bucket_tls_only" {
  statement {
    sid     = "DenyInsecureConnections"
    effect  = "Deny"
    actions = ["s3:*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = [
      aws_s3_bucket.spill.arn,
      "${aws_s3_bucket.spill.arn}/*",
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "spill" {
  bucket = aws_s3_bucket.spill.id
  policy = data.aws_iam_policy_document.spill_bucket_tls_only.json
}
