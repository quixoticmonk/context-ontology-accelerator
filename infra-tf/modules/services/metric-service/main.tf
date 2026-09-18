# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Metric service data plane: import-jobs DynamoDB table, SQS import
# queue + DLQ, OSI staging S3 bucket (+ access logs bucket), the AOSS
# data-access policy + VPC endpoint ingress rule, and SSM writes.
#
# Lambdas + their IAM live in api_lambdas.tf.

# AWS-managed KMS key for DynamoDB (kms_key_arn on server_side_encryption
# is required by CKV_AWS_119 even when using the aws/dynamodb key). Making
# it explicit vs. relying on the default so intent is auditable.
data "aws_kms_alias" "dynamodb" {
  name = "alias/aws/dynamodb"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ═════════════════════════════════════════════════════════════════════
#  DynamoDB — import jobs table
# ═════════════════════════════════════════════════════════════════════
# PK/SK strings, PAY_PER_REQUEST, AWS-managed SSE, TTL on `ttl`.
# Matches CDK ImportJobsTable. The CDK does not enable PITR or streams
# on this table, so neither is set here.
resource "aws_dynamodb_table" "import_jobs" {
  name         = local.import_jobs_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = data.aws_kms_alias.dynamodb.target_key_arn
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  SQS — import queue + DLQ
# ═════════════════════════════════════════════════════════════════════
# DLQ: 14-day retention, SQS-managed SSE. Queue: 15-minute visibility
# timeout (matches worker timeout), 4-day retention, redrive to DLQ
# after 3 receives. Matches CDK ImportQueue / ImportDLQ.
resource "aws_sqs_queue" "import_dlq" {
  name                      = local.import_dlq_name
  message_retention_seconds = 1209600 # 14 days
  sqs_managed_sse_enabled   = true

  tags = local.tags
}

resource "aws_sqs_queue" "import" {
  name                       = local.import_queue_name
  visibility_timeout_seconds = 900    # 15 minutes
  message_retention_seconds  = 345600 # 4 days
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.import_dlq.arn
    maxReceiveCount     = 3
  })

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  S3 — OSI import/export staging bucket (+ access logs)
# ═════════════════════════════════════════════════════════════════════
# Server access logs sink. Encrypted, public access blocked, TLS-only.
resource "aws_s3_bucket" "osi_logs" {
  bucket        = local.osi_logs_bucket_name
  force_destroy = true

  tags = local.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "osi_logs" {
  bucket = aws_s3_bucket.osi_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "osi_logs" {
  bucket = aws_s3_bucket.osi_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 log delivery writes with the bucket-owner-enforced default; grant
# the logging service principal PutObject on the log prefix.
resource "aws_s3_bucket_policy" "osi_logs" {
  bucket = aws_s3_bucket.osi_logs.id
  policy = data.aws_iam_policy_document.osi_logs.json
}

data "aws_iam_policy_document" "osi_logs" {
  statement {
    sid     = "AllowS3ServerAccessLogs"
    actions = ["s3:PutObject"]

    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }

    resources = ["${aws_s3_bucket.osi_logs.arn}/metric-osi/*"]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.osi.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.osi_logs.arn, "${aws_s3_bucket.osi_logs.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# OSI staging bucket. S3-managed SSE, public access blocked, TLS-only,
# CORS for browser PUT/GET, 1-day expiration on uploaded/exported
# files. Matches CDK OsiBucket.
resource "aws_s3_bucket" "osi" {
  bucket        = local.osi_bucket_name
  force_destroy = true

  tags = local.tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "osi" {
  bucket = aws_s3_bucket.osi.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "osi" {
  bucket = aws_s3_bucket.osi.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "osi" {
  bucket        = aws_s3_bucket.osi.id
  target_bucket = aws_s3_bucket.osi_logs.id
  target_prefix = "metric-osi/"
}

resource "aws_s3_bucket_cors_configuration" "osi" {
  bucket = aws_s3_bucket.osi.id

  # See modules/foundation/storage/s3.tf ontology_artifacts CORS for the
  # rationale — allow-all headers is required for the browser to receive
  # the CORS response on a presigned PUT preflight; without it OSI import
  # fails as an opaque "Failed to fetch" in the UI.
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "GET"]
    allowed_origins = [var.allowed_origin]
    expose_headers  = ["ETag", "Content-Length", "Content-Type"]
    max_age_seconds = 3600
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "osi" {
  bucket = aws_s3_bucket.osi.id

  rule {
    id     = "expire-staging-objects"
    status = "Enabled"

    filter {}

    expiration {
      days = 1
    }
  }
}

resource "aws_s3_bucket_policy" "osi" {
  bucket = aws_s3_bucket.osi.id
  policy = data.aws_iam_policy_document.osi.json
}

data "aws_iam_policy_document" "osi" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.osi.arn, "${aws_s3_bucket.osi.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# ═════════════════════════════════════════════════════════════════════
#  AOSS — VPC endpoint ingress + data-access policy
# ═════════════════════════════════════════════════════════════════════
# Allow the Lambda SG to reach the AOSS VPC endpoint on 443. The AOSS
# SG is owned by the network module; this rule attaches to it.
resource "aws_vpc_security_group_ingress_rule" "aoss_from_lambda" {
  security_group_id            = var.aoss_security_group_id
  referenced_security_group_id = var.lambda_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "Allow HTTPS from metric Lambda to AOSS VPC endpoint"

  tags = local.tags
}

# AOSS requires a data-access policy in addition to IAM permissions.
# Names both Lambda roles as principals so each can read/write docs and
# manage indexes in the collection. Matches CDK OSSDataAccessPolicy
# (extended to both roles — the CDK only named the API role at author
# time, but the worker performs the same index writes).
resource "aws_opensearchserverless_access_policy" "data" {
  name = "${var.name_prefix}-metric-data-access"
  type = "data"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index"
          Resource     = ["index/${var.opensearch_collection_name}/*"]
          Permission = [
            "aoss:CreateIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument",
          ]
        },
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.opensearch_collection_name}"]
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DescribeCollectionItems",
            "aoss:UpdateCollectionItems",
          ]
        },
      ]
      Principal = [
        aws_iam_role.metric_api.arn,
        aws_iam_role.import_worker.arn,
      ]
    },
  ])
}

# ═════════════════════════════════════════════════════════════════════
#  SSM writes
# ═════════════════════════════════════════════════════════════════════
resource "aws_ssm_parameter" "metric_api_fn_arn" {
  name  = "${var.ssm_prefix}/metric/api-fn-arn"
  type  = "String"
  value = aws_lambda_function.metric_api.arn
  tags  = local.tags
}

resource "aws_ssm_parameter" "import_jobs_table_name" {
  name  = "${var.ssm_prefix}/metric/import-jobs-table-name"
  type  = "String"
  value = aws_dynamodb_table.import_jobs.name
  tags  = local.tags
}

resource "aws_ssm_parameter" "import_queue_url" {
  name  = "${var.ssm_prefix}/metric/import-queue-url"
  type  = "String"
  value = aws_sqs_queue.import.url
  tags  = local.tags
}
