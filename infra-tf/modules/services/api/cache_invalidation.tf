# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Cache-invalidation Lambda. Triggered by DynamoDB Streams on the
# Roles and ResourceRoleMappings tables. On any change, bumps the
# version counter in the CacheInvalidation table so the authorizer
# clears its local cache.
#
# Retry indefinitely within the 24h stream retention, then park failed
# records in a DLQ. A DLQ message means a revoked role stayed cached —
# the CloudWatch alarm below pages on any DLQ message.

# ── Role + policies ─────────────────────────────────────────────────
resource "aws_iam_role" "cache_invalidation" {
  name               = "${local.cache_inval_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "cache_invalidation_vpc" {
  role       = aws_iam_role.cache_invalidation.name
  policy_arn = data.aws_iam_policy.lambda_vpc_access.arn
}

data "aws_iam_policy_document" "cache_invalidation" {
  # atomic_increment on the CacheInvalidation table.
  statement {
    sid = "CacheInvalidationTableWrite"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
    ]
    resources = [var.cache_invalidation_table_arn]
  }

  # Read from the two source streams.
  statement {
    sid = "DdbStreamsRead"
    actions = [
      "dynamodb:GetRecords",
      "dynamodb:GetShardIterator",
      "dynamodb:DescribeStream",
      "dynamodb:ListStreams",
    ]
    resources = [
      var.roles_table_stream_arn,
      var.resource_role_mappings_table_stream_arn,
    ]
  }

  # Park failed records in the DLQ.
  statement {
    sid       = "DlqSend"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.cache_invalidation_dlq.arn]
  }
}

resource "aws_iam_policy" "cache_invalidation" {
  name   = "${local.cache_inval_name}-policy"
  policy = data.aws_iam_policy_document.cache_invalidation.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "cache_invalidation" {
  role       = aws_iam_role.cache_invalidation.name
  policy_arn = aws_iam_policy.cache_invalidation.arn
}

# ── Lambda ──────────────────────────────────────────────────────────
resource "aws_lambda_function" "cache_invalidation" {
  function_name    = local.cache_inval_name
  role             = aws_iam_role.cache_invalidation.arn
  runtime          = "python3.12"
  handler          = "coa_control_plane.authorization.stream_handler.handler"
  filename         = var.control_plane_zip_path
  source_code_hash = try(filebase64sha256(var.control_plane_zip_path), null)
  timeout          = 10
  memory_size      = 128

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      CACHE_INVALIDATION_TABLE_NAME = var.cache_invalidation_table_name
    }
  }

  tags = local.tags
}

# ── DLQ ─────────────────────────────────────────────────────────────
resource "aws_sqs_queue" "cache_invalidation_dlq" {
  name                      = "${local.cache_inval_name}-dlq"
  sqs_managed_sse_enabled   = true
  message_retention_seconds = 1209600 # 14 days

  tags = local.tags
}

data "aws_iam_policy_document" "cache_invalidation_dlq_ssl" {
  statement {
    sid     = "DenyInsecureConnections"
    effect  = "Deny"
    actions = ["sqs:*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [aws_sqs_queue.cache_invalidation_dlq.arn]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_sqs_queue_policy" "cache_invalidation_dlq" {
  queue_url = aws_sqs_queue.cache_invalidation_dlq.id
  policy    = data.aws_iam_policy_document.cache_invalidation_dlq_ssl.json
}

# ── Event source mappings (both tables' streams) ────────────────────

resource "aws_lambda_event_source_mapping" "roles_stream" {
  event_source_arn                   = var.roles_table_stream_arn
  function_name                      = aws_lambda_function.cache_invalidation.arn
  starting_position                  = "LATEST"
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  # -1 = retry until the record ages out of the 24h stream retention.
  maximum_retry_attempts = -1

  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.cache_invalidation_dlq.arn
    }
  }
}

resource "aws_lambda_event_source_mapping" "rrm_stream" {
  event_source_arn                   = var.resource_role_mappings_table_stream_arn
  function_name                      = aws_lambda_function.cache_invalidation.arn
  starting_position                  = "LATEST"
  batch_size                         = 10
  maximum_batching_window_in_seconds = 5
  maximum_retry_attempts             = -1

  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.cache_invalidation_dlq.arn
    }
  }
}

# ── Alarm: any message in the DLQ ──────────────────────────────────
# A DLQ message means an invalidation was dropped after 24h of retries
# — the authorizer's version counter never moved for that grant change,
# so a revoked role can stay cached until the per-entry TTL expires.
# The alarm exists to avoid silent loss.
resource "aws_cloudwatch_metric_alarm" "cache_invalidation_dlq" {
  alarm_name        = "${local.cache_inval_name}-dlq"
  alarm_description = "Cache-invalidation records landed in the DLQ — authorizer role cache may be serving revoked roles until TTL expiry"

  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.cache_invalidation_dlq.name
  }

  tags = local.tags
}
