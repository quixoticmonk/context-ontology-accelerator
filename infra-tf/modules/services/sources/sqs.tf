# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Seven SQS queues (4 primary + 3 DLQs) matching the CDK sources stack.
# Per-queue visibility and encryption settings match the CDK exactly.

# ═════════════════════════════════════════════════════════════════════
#  DB Connector DLQ (Lambda-native DLQ, no matching queue)
# ═════════════════════════════════════════════════════════════════════
# Attached to the discovery Lambda as its Lambda-native deadLetterQueue.
# 14-day retention. No matching primary queue — the discovery Lambda is
# invoked directly by the Step Function, not via SQS.
resource "aws_sqs_queue" "db_connector_dlq" {
  name                      = "${var.name_prefix}-sources-db-connector-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = "alias/aws/sqs"

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  DB Scan Queue + DLQ
# ═════════════════════════════════════════════════════════════════════
# Feeds the dbTriggerFn which starts the dbScanStateMachine execution.
# Encrypted with SSE-KMS (aws/sqs). 90s visibility (Lambda hands off to
# SFN before it returns). maxReceive 3 before DLQ.
resource "aws_sqs_queue" "db_scan_dlq" {
  name                      = "${var.name_prefix}-sources-db-scan-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = "alias/aws/sqs"

  tags = local.tags
}

resource "aws_sqs_queue" "db_scan" {
  name                       = "${var.name_prefix}-sources-db-scan-queue"
  visibility_timeout_seconds = 90
  kms_master_key_id          = "alias/aws/sqs"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.db_scan_dlq.arn
    maxReceiveCount     = 3
  })

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  Bulk Review Queue + DLQ
# ═════════════════════════════════════════════════════════════════════
# Async pipeline for ApproveSource/RejectSource — the API Lambda
# enqueues and returns 202, then the worker performs the actual
# DataZone asset revisions. 6-min visibility (slightly above the 5-min
# worker Lambda timeout so a message stays invisible until the worker
# has finished). enforceSSL matches CDK.
resource "aws_sqs_queue" "bulk_review_dlq" {
  name                      = "${var.name_prefix}-sources-bulk-review-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = "alias/aws/sqs"

  tags = local.tags
}

resource "aws_sqs_queue" "bulk_review" {
  name                       = "${var.name_prefix}-sources-bulk-review-queue"
  visibility_timeout_seconds = 360 # 6 minutes
  kms_master_key_id          = "alias/aws/sqs"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.bulk_review_dlq.arn
    maxReceiveCount     = 3
  })

  tags = local.tags
}

# Enforce SSL on the bulk-review queue (CDK enforceSSL: true).
data "aws_iam_policy_document" "bulk_review_ssl" {
  statement {
    sid     = "DenyInsecureConnections"
    effect  = "Deny"
    actions = ["sqs:*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [aws_sqs_queue.bulk_review.arn]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "bulk_review" {
  queue_url = aws_sqs_queue.bulk_review.id
  policy    = data.aws_iam_policy_document.bulk_review_ssl.json
}

# ═════════════════════════════════════════════════════════════════════
#  Documents Ingestion Queue + DLQ
# ═════════════════════════════════════════════════════════════════════
# Feeds the docTriggerFn which starts the docIngestionStateMachine
# execution. 900s visibility. maxReceive 3 before DLQ.
resource "aws_sqs_queue" "doc_ingestion_dlq" {
  name                      = "${var.name_prefix}-sources-doc-ingestion-dlq"
  message_retention_seconds = 1209600
  kms_master_key_id         = "alias/aws/sqs"

  tags = local.tags
}

resource "aws_sqs_queue" "doc_ingestion" {
  name                       = "${var.name_prefix}-sources-doc-ingestion-queue"
  visibility_timeout_seconds = 900
  kms_master_key_id          = "alias/aws/sqs"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.doc_ingestion_dlq.arn
    maxReceiveCount     = 3
  })

  tags = local.tags
}
