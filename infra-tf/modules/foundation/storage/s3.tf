# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# S3 buckets: athena-results, athena-spill, ontology-artifacts, plus a
# shared access-logs target. AWS provider v6 requires the per-concern
# sub-resources (versioning, encryption, lifecycle, CORS, public-access-
# block, policy) as SEPARATE resources rather than inline bucket blocks.
#
# All buckets: SSE-S3, block-all-public-access, SSL-enforced bucket
# policy. Non-prod force_destroy = true (clean teardown); prod
# force_destroy = false with prevent_destroy to protect data.

# =====================================================================
#  Access-logs target bucket
#
#  Server-access-log target for the three source buckets. Intentionally
#  NOT self-logging (that would create a delivery loop) — the accepted
#  exception for a log-archive bucket. Logs expire after 90 days.
# =====================================================================
resource "aws_s3_bucket" "access_logs" {
  bucket        = "${var.name_prefix}-storage-logs-${local.account_id}"
  force_destroy = local.force_destroy_buckets

  tags = { Component = var.component }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket policy: enforce SSL/TLS AND allow the S3 logging service to
# deliver server access logs from the three source buckets.
data "aws_iam_policy_document" "access_logs" {
  statement {
    sid       = "EnforceTLS"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.access_logs.arn, "${aws_s3_bucket.access_logs.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "AllowS3ServerAccessLogging"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.access_logs.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = data.aws_iam_policy_document.access_logs.json

  depends_on = [aws_s3_bucket_public_access_block.access_logs]
}

# =====================================================================
#  athena-results bucket — 7-day expiration
# =====================================================================
resource "aws_s3_bucket" "athena_results" {
  bucket        = "${var.name_prefix}-athena-results-${local.account_id}"
  force_destroy = local.force_destroy_buckets

  tags = { Component = var.component }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "expire-results"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }
  }
}

# =====================================================================
#  athena-spill bucket — 1-day expiration
# =====================================================================
resource "aws_s3_bucket" "athena_spill" {
  bucket        = "${var.name_prefix}-athena-spill-${local.account_id}"
  force_destroy = local.force_destroy_buckets

  tags = { Component = var.component }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "athena_spill" {
  bucket = aws_s3_bucket.athena_spill.id

  rule {
    id     = "expire-spill"
    status = "Enabled"

    filter {}

    expiration {
      days = 1
    }
  }
}

# =====================================================================
#  ontology-artifacts bucket — versioned, CORS for presigned PUT/GET
# =====================================================================
resource "aws_s3_bucket" "ontology_artifacts" {
  bucket        = "${var.name_prefix}-ontology-artifacts-${local.account_id}"
  force_destroy = local.force_destroy_buckets

  tags = { Component = var.component }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_cors_configuration" "ontology_artifacts" {
  bucket = aws_s3_bucket.ontology_artifacts.id

  cors_rule {
    allowed_headers = ["Content-Type"]
    allowed_methods = ["GET", "HEAD", "PUT"]
    allowed_origins = [var.allowed_origin]
    max_age_seconds = 3600
  }
}

# =====================================================================
#  Shared per-concern sub-resources for the three logged buckets
#
#  versioning: athena buckets Disabled, ontology-artifacts Enabled.
#  encryption + public-access-block + SSL policy + server-access-logging
#  are identical across all three, so they fan out via for_each.
# =====================================================================
resource "aws_s3_bucket_versioning" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_versioning" "athena_spill" {
  bucket = aws_s3_bucket.athena_spill.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_versioning" "ontology_artifacts" {
  bucket = aws_s3_bucket.ontology_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logged" {
  for_each = local.logged_buckets

  bucket = each.value.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logged" {
  for_each = local.logged_buckets

  bucket = each.value.bucket

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "logged" {
  for_each = local.logged_buckets

  bucket        = each.value.bucket
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "${replace(each.key, "_", "-")}/"
}

# SSL-enforce bucket policy for each logged bucket.
data "aws_iam_policy_document" "enforce_tls" {
  for_each = local.logged_buckets

  statement {
    sid       = "EnforceTLS"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [each.value.arn, "${each.value.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "logged" {
  for_each = local.logged_buckets

  bucket = each.value.bucket
  policy = data.aws_iam_policy_document.enforce_tls[each.key].json

  depends_on = [aws_s3_bucket_public_access_block.logged]
}
