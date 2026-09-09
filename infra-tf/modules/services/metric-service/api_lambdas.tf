# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Two Lambdas: metric_api (synchronous CRUD + async import trigger) and
# import_worker (SQS-driven async import). Both share the same
# metric-service zip (produced by the module's Makefile) and run in the
# platform VPC.
#
# Every Lambda gets its own execution role — matches CDK's per-function
# role model. The AWSLambdaVPCAccessExecutionRole managed policy grants
# ENI create/describe/delete + CloudWatch Logs; per-Lambda inline
# policies add the specific grants each handler needs.

# ═════════════════════════════════════════════════════════════════════
#  Shared trust + managed VPC-access policy
# ═════════════════════════════════════════════════════════════════════

data "aws_iam_policy" "vpc_access" {
  arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ═════════════════════════════════════════════════════════════════════
#  1. Metric API Lambda
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "metric_api" {
  name               = "${local.fn_metric_api}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "metric_api_vpc" {
  role       = aws_iam_role.metric_api.name
  policy_arn = data.aws_iam_policy.vpc_access.arn
}

data "aws_iam_policy_document" "metric_api_policy" {
  # S3 (OSI import/export)
  statement {
    sid       = "OsiObjectRW"
    actions   = ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.osi.arn}/*"]
  }

  # Neptune (SPARQL read/write/delete)
  statement {
    sid = "NeptuneData"
    actions = [
      "neptune-db:ReadDataViaQuery",
      "neptune-db:WriteDataViaQuery",
      "neptune-db:DeleteDataViaQuery",
    ]
    resources = [var.neptune_cluster_arn]
  }

  # OpenSearch Serverless
  statement {
    sid       = "AossApiAccess"
    actions   = ["aoss:APIAccessAll"]
    resources = [var.opensearch_collection_arn]
  }

  # Bedrock (embedding generation) — inference profile + underlying
  # foundation models the profile fans out to.
  statement {
    sid       = "BedrockInvoke"
    actions   = ["bedrock:InvokeModel"]
    resources = local.bedrock_invoke_resources
  }

  # EventBridge (lifecycle events)
  statement {
    sid       = "EventBridgePutEvents"
    actions   = ["events:PutEvents"]
    resources = ["arn:${data.aws_partition.current.partition}:events:${var.region}:${data.aws_caller_identity.current.account_id}:event-bus/${var.event_bus_name}"]
  }

  # SMUS catalog: read-only on sources + namespaces tables
  statement {
    sid = "SmusCatalogRead"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = [
      local.sources_table_arn,
      "${local.sources_table_arn}/index/*",
      local.namespaces_table_arn,
      "${local.namespaces_table_arn}/index/*",
    ]
  }

  # DynamoDB: import-jobs R/W (API enqueues + tracks async imports)
  statement {
    sid = "ImportJobsRW"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [
      aws_dynamodb_table.import_jobs.arn,
      "${aws_dynamodb_table.import_jobs.arn}/index/*",
    ]
  }

  # SQS: send messages to the import queue
  statement {
    sid       = "ImportQueueSend"
    actions   = ["sqs:SendMessage", "sqs:GetQueueAttributes", "sqs:GetQueueUrl"]
    resources = [aws_sqs_queue.import.arn]
  }

  # SMUS: assume the shared DataZone project access role
  dynamic "statement" {
    for_each = var.smus_project_access_role_arn != null ? [1] : []
    content {
      sid       = "SmusAssumeProjectRole"
      actions   = ["sts:AssumeRole"]
      resources = [var.smus_project_access_role_arn]
    }
  }
}

resource "aws_iam_policy" "metric_api" {
  name   = "${local.fn_metric_api}-policy"
  policy = data.aws_iam_policy_document.metric_api_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "metric_api" {
  role       = aws_iam_role.metric_api.name
  policy_arn = aws_iam_policy.metric_api.arn
}

resource "aws_lambda_function" "metric_api" {
  function_name    = local.fn_metric_api
  role             = aws_iam_role.metric_api.arn
  runtime          = "python3.12"
  handler          = "coa_metrics.api.metric_api_handler.handler"
  filename         = var.metric_service_zip_path
  source_code_hash = local.lambda_zip_hash
  timeout          = 30
  memory_size      = 512

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = local.metric_api_env
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  2. Import Worker Lambda
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "import_worker" {
  name               = "${local.fn_import_worker}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "import_worker_vpc" {
  role       = aws_iam_role.import_worker.name
  policy_arn = data.aws_iam_policy.vpc_access.arn
}

data "aws_iam_policy_document" "import_worker_policy" {
  # Neptune (SPARQL read/write/delete + connect)
  statement {
    sid = "NeptuneData"
    actions = [
      "neptune-db:ReadDataViaQuery",
      "neptune-db:WriteDataViaQuery",
      "neptune-db:DeleteDataViaQuery",
      "neptune-db:connect",
    ]
    resources = [var.neptune_cluster_arn]
  }

  # OpenSearch Serverless
  statement {
    sid       = "AossApiAccess"
    actions   = ["aoss:APIAccessAll"]
    resources = [var.opensearch_collection_arn]
  }

  # Bedrock (embedding generation)
  statement {
    sid       = "BedrockInvoke"
    actions   = ["bedrock:InvokeModel"]
    resources = local.bedrock_invoke_resources
  }

  # S3: read staged OSI objects
  statement {
    sid       = "OsiObjectRead"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [aws_s3_bucket.osi.arn, "${aws_s3_bucket.osi.arn}/*"]
  }

  # SMUS catalog: read-only on sources + namespaces tables
  statement {
    sid = "SmusCatalogRead"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:BatchGetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = [
      local.sources_table_arn,
      "${local.sources_table_arn}/index/*",
      local.namespaces_table_arn,
      "${local.namespaces_table_arn}/index/*",
    ]
  }

  # DynamoDB: import-jobs R/W (worker updates job status)
  statement {
    sid = "ImportJobsRW"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [
      aws_dynamodb_table.import_jobs.arn,
      "${aws_dynamodb_table.import_jobs.arn}/index/*",
    ]
  }

  # SQS: send messages (re-enqueue) + consume from the import queue.
  # Consume actions match the event source mapping's poller needs.
  statement {
    sid = "ImportQueueConsume"
    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
    ]
    resources = [aws_sqs_queue.import.arn]
  }

  # SMUS: assume the shared DataZone project access role
  dynamic "statement" {
    for_each = var.smus_project_access_role_arn != null ? [1] : []
    content {
      sid       = "SmusAssumeProjectRole"
      actions   = ["sts:AssumeRole"]
      resources = [var.smus_project_access_role_arn]
    }
  }
}

resource "aws_iam_policy" "import_worker" {
  name   = "${local.fn_import_worker}-policy"
  policy = data.aws_iam_policy_document.import_worker_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "import_worker" {
  role       = aws_iam_role.import_worker.name
  policy_arn = aws_iam_policy.import_worker.arn
}

resource "aws_lambda_function" "import_worker" {
  function_name    = local.fn_import_worker
  role             = aws_iam_role.import_worker.arn
  runtime          = "python3.12"
  handler          = "coa_metrics.api.import_worker.handler"
  filename         = var.metric_service_zip_path
  source_code_hash = local.lambda_zip_hash
  timeout          = 900
  memory_size      = 512

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = local.import_worker_env
  }

  tags = local.tags
}

# Worker triggered by SQS (batch size 1 — each message is one chunk).
resource "aws_lambda_event_source_mapping" "import_worker" {
  event_source_arn = aws_sqs_queue.import.arn
  function_name    = aws_lambda_function.import_worker.arn
  batch_size       = 1
}
