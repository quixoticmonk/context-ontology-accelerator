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

# ═════════════════════════════════════════════════════════════════════
#  Source-delete worker queue + DLQ (v0.3.5 async DELETE flow)
# ═════════════════════════════════════════════════════════════════════
# DELETE /sources/{sourceId} enqueues here instead of running cleanup
# inline, so the API returns 202+DELETING in <30s while the worker
# finishes the DataZone teardown within its 15-min envelope. Visibility
# MUST exceed the worker's timeout — 16min here vs the worker's 15min —
# or SQS redelivers to a still-running handler and duplicates cleanup.
resource "aws_sqs_queue" "source_delete_dlq" {
  name                      = "${var.name_prefix}-sources-delete-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = "alias/aws/sqs"

  tags = local.tags
}

resource "aws_sqs_queue" "source_delete" {
  name                       = "${var.name_prefix}-sources-delete-queue"
  visibility_timeout_seconds = 960 # 16 minutes (worker is 15)
  kms_master_key_id          = "alias/aws/sqs"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.source_delete_dlq.arn
    maxReceiveCount     = 3
  })

  tags = local.tags
}

# Deny non-TLS (CDK enforceSSL: true).
data "aws_iam_policy_document" "source_delete_ssl" {
  statement {
    sid     = "DenyInsecureConnections"
    effect  = "Deny"
    actions = ["sqs:*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = [aws_sqs_queue.source_delete.arn]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "source_delete" {
  queue_url = aws_sqs_queue.source_delete.id
  policy    = data.aws_iam_policy_document.source_delete_ssl.json
}

# ═════════════════════════════════════════════════════════════════════
#  Glue-event rescan queue + DLQ (v0.3.5 event-driven rescans)
# ═════════════════════════════════════════════════════════════════════
# Per-source EventBridge rules (created at runtime by the sources-api
# Lambda) match a source's Glue catalog changes and route to this queue.
# A consumer Lambda drains it into EVENT rescans. SQS-as-target rather
# than Lambda-direct avoids per-rule Lambda permission churn; the queue
# policy grants EventBridge instead.
resource "aws_sqs_queue" "glue_event_dlq" {
  name                      = "${var.name_prefix}-sources-glue-event-dlq"
  message_retention_seconds = 1209600 # 14 days
  kms_master_key_id         = "alias/aws/sqs"

  tags = local.tags
}

resource "aws_sqs_queue" "glue_event" {
  name                       = "${var.name_prefix}-sources-glue-event-queue"
  visibility_timeout_seconds = 180 # 6x the consumer's 30s timeout (AWS guidance)
  kms_master_key_id          = "alias/aws/sqs"

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.glue_event_dlq.arn
    maxReceiveCount     = 5
  })

  tags = local.tags
}

# Resource policy: allow EventBridge rules in THIS account to deliver,
# plus deny non-TLS. The CDK merged the two into one policy document;
# we do the same here so both statements apply as one queue policy.
data "aws_iam_policy_document" "glue_event" {
  # The sources-api Lambda names every per-source rule
  # `<name_prefix>-sources-glue-rescan-<sourceId>` and puts it on the
  # default event bus (whose rule ARNs are `rule/<name>`). One ARN pattern
  # serves both this queue policy and the API Lambda's rule-management
  # grant in iam_db.tf, so the two cannot drift: a rule the Lambda may
  # create is exactly a rule the queue accepts.
  statement {
    sid     = "AllowEventBridgeSend"
    effect  = "Allow"
    actions = ["sqs:SendMessage"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    resources = [aws_sqs_queue.glue_event.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
    # Allow only this deployment's own Glue re-scan rules to deliver.
    # Without this, any rule anyone in the account creates against the
    # default event bus could deliver here — the account check alone
    # admits every sibling deployment's rules too.
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:events:${var.region}:${data.aws_caller_identity.current.account_id}:rule/${var.name_prefix}-sources-glue-rescan-*"]
    }
  }

  statement {
    sid     = "DenyInsecureConnections"
    effect  = "Deny"
    actions = ["sqs:*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = [aws_sqs_queue.glue_event.arn]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "glue_event" {
  queue_url = aws_sqs_queue.glue_event.id
  policy    = data.aws_iam_policy_document.glue_event.json
}

# ═════════════════════════════════════════════════════════════════════
#  TLS-deny policies on remaining queues (v0.3.5 parity)
# ═════════════════════════════════════════════════════════════════════
# Upstream v0.3.5 added `enforceSSL: true` to every SQS queue in the
# sources stack. The CDK's enforceSSL compiles to the exact deny-non-TLS
# statement below. Pre-v0.3.5 only BulkReviewQueue carried it; after,
# every queue + DLQ does. The three queues added in the v0.3.5 flows
# (source_delete, glue_event, and their DLQs) already carry the policy
# from the compute_delete_rescan tf port; this block covers the
# pre-existing queues that upstream retrofitted.

locals {
  # Queues that need ONLY the fleet-wide TLS-deny policy (no bespoke
  # permissions). `db_connector_dlq` is deliberately absent: it has a
  # merged policy in compute_db.tf (SendMessage grant + DenyInsecure
  # in one resource) because SQS allows only one policy per queue.
  tls_deny_queues = {
    db_scan           = aws_sqs_queue.db_scan.arn
    db_scan_dlq       = aws_sqs_queue.db_scan_dlq.arn
    bulk_review_dlq   = aws_sqs_queue.bulk_review_dlq.arn
    doc_ingestion     = aws_sqs_queue.doc_ingestion.arn
    doc_ingestion_dlq = aws_sqs_queue.doc_ingestion_dlq.arn
    source_delete_dlq = aws_sqs_queue.source_delete_dlq.arn
    glue_event_dlq    = aws_sqs_queue.glue_event_dlq.arn
  }
}

data "aws_iam_policy_document" "tls_deny_queues" {
  for_each = local.tls_deny_queues

  statement {
    sid     = "DenyInsecureConnections"
    effect  = "Deny"
    actions = ["sqs:*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = [each.value]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "tls_deny" {
  for_each = local.tls_deny_queues

  # Resolve from each key, since queue_url/aws_sqs_queue.XXX.id can't
  # be dynamically indexed on the ARN alone.
  queue_url = {
    db_scan           = aws_sqs_queue.db_scan.id
    db_scan_dlq       = aws_sqs_queue.db_scan_dlq.id
    bulk_review_dlq   = aws_sqs_queue.bulk_review_dlq.id
    doc_ingestion     = aws_sqs_queue.doc_ingestion.id
    doc_ingestion_dlq = aws_sqs_queue.doc_ingestion_dlq.id
    source_delete_dlq = aws_sqs_queue.source_delete_dlq.id
    glue_event_dlq    = aws_sqs_queue.glue_event_dlq.id
  }[each.key]

  policy = data.aws_iam_policy_document.tls_deny_queues[each.key].json
}
