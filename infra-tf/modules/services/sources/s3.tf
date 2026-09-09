# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Two S3 buckets: sources-data (uploads + preprocessed staging) and
# a shared access-logs target. Both v6-style — versioning, encryption,
# lifecycle, CORS, public-access-block as separate resources.

# ═════════════════════════════════════════════════════════════════════
#  Access logs bucket
# ═════════════════════════════════════════════════════════════════════
# Server-access-log target for the sources-data bucket. Matches the
# AccessLogsBucket construct in the CDK — enforces SSL, blocks public
# access, allows logging.s3.amazonaws.com PutObject.

resource "aws_s3_bucket" "access_logs" {
  bucket        = local.sources_access_logs_name
  force_destroy = local.force_destroy_buckets

  tags = local.tags
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    # Required for `LogDeliveryWrite` acl semantics; access-logs bucket
    # accepts writes from the logging.s3.amazonaws.com service principal.
    object_ownership = "BucketOwnerPreferred"
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

data "aws_iam_policy_document" "access_logs_policy" {
  # Allow logging.s3.amazonaws.com to PutObject.
  statement {
    sid     = "S3ServerAccessLogsDelivery"
    actions = ["s3:PutObject"]

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    resources = ["${aws_s3_bucket.access_logs.arn}/*"]
  }

  # Enforce TLS on all bucket access.
  statement {
    sid     = "DenyInsecureConnections"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.access_logs.arn,
      "${aws_s3_bucket.access_logs.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = data.aws_iam_policy_document.access_logs_policy.json
}

# ═════════════════════════════════════════════════════════════════════
#  sources-data bucket
# ═════════════════════════════════════════════════════════════════════
# Raw document uploads + pre-processed staging output. Versioned,
# SSE-S3, blocks public access, TLS-only, CORS PUT for presigned
# uploads. Objects under `extracted/` expire after 30 days (staging
# artifacts, not source of truth).

resource "aws_s3_bucket" "sources_data" {
  bucket        = local.sources_bucket_name
  force_destroy = local.force_destroy_buckets

  tags = local.tags
}

resource "aws_s3_bucket_public_access_block" "sources_data" {
  bucket                  = aws_s3_bucket.sources_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "sources_data" {
  bucket = aws_s3_bucket.sources_data.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sources_data" {
  bucket = aws_s3_bucket.sources_data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "sources_data" {
  bucket = aws_s3_bucket.sources_data.id

  rule {
    id     = "expire-extracted-staging"
    status = "Enabled"

    filter {
      prefix = "extracted/"
    }

    expiration {
      days = 30
    }
  }
}

resource "aws_s3_bucket_cors_configuration" "sources_data" {
  bucket = aws_s3_bucket.sources_data.id

  cors_rule {
    allowed_methods = ["PUT"]
    allowed_origins = [var.allowed_origin]
    allowed_headers = ["Content-Type"]
    max_age_seconds = 3600
  }
}

resource "aws_s3_bucket_logging" "sources_data" {
  bucket        = aws_s3_bucket.sources_data.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "sources-data/"
}

data "aws_iam_policy_document" "sources_data_policy" {
  statement {
    sid     = "DenyInsecureConnections"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.sources_data.arn,
      "${aws_s3_bucket.sources_data.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "sources_data" {
  bucket = aws_s3_bucket.sources_data.id
  policy = data.aws_iam_policy_document.sources_data_policy.json
}
