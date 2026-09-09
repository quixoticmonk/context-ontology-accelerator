# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IAM for the documents-side sources pipeline. Roles:
#   1. preprocessing            — S3 read (customer + platform + sources)
#   2. kg_build_execution/task  — Fargate task
#   3. batch_inference          — Bedrock batch job service role
#   4. doc_cleanup              — S3 + DDB cleanup on deletion
#   5. doc_trigger              — SQS → docIngestion SFN trigger
#   6. sfn_doc_ingestion        — docIngestion state-machine role
#   7. sfn_doc_deletion         — docDeletion state-machine role
#
# Load-bearing security guards preserved from CDK:
#   - `ReadCustomerSourceBuckets`  wildcard + tag verification in handler
#   - `DenyPlatformOwnedBuckets`   fail-closed Deny mirroring the Allow
#   - `preprocessing` sts:AssumeRole scoped to `${resource_prefix}-*` roles
#   - batch_inference trust with SourceAccount + SourceArn conditions

# ═════════════════════════════════════════════════════════════════════
#  1. Preprocessing Lambda role (DockerImageFunction)
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "preprocessing" {
  name               = "${var.name_prefix}-sources-doc-preprocessing-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "preprocessing_vpc" {
  role       = aws_iam_role.preprocessing.name
  policy_arn = data.aws_iam_policy.lambda_vpc_access.arn
}

data "aws_iam_policy_document" "preprocessing" {
  # Sources data bucket — read/write for uploads + preprocessing staging.
  # Deliberately not gated by the DenyPlatformOwnedBuckets below (CDK
  # says: sources data bucket is deliberately absent from the deny list).
  statement {
    sid = "SourcesDataBucketReadWrite"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket",
      "s3:AbortMultipartUpload", "s3:GetObjectTagging",
    ]
    resources = [
      aws_s3_bucket.sources_data.arn,
      "${aws_s3_bucket.sources_data.arn}/*",
    ]
  }

  # Sources table read/write.
  statement {
    sid = "SourcesTableAccess"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "dynamodb:Query",
    ]
    resources = [
      aws_dynamodb_table.sources.arn,
      "${aws_dynamodb_table.sources.arn}/index/*",
    ]
  }

  # Customer-provided source buckets — wildcard required (customer's
  # bucket name is not knowable at synth). Authorization for these
  # buckets is the owner-set `{prefix}:namespace` tag, verified in the
  # preprocessing handler. GetBucketTagging is on the wildcard too
  # because whether we may read a bucket is exactly what that call
  # answers, so it cannot be scoped by the answer.
  statement {
    sid = "ReadCustomerSourceBuckets"
    actions = [
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:ListBucket",
      "s3:GetBucketTagging",
    ]
    resources = ["*"]
  }

  # Fail-closed Deny mirroring the Allow above. Prevents the wildcard
  # ReadCustomerSourceBuckets grant from reaching Athena results, spill,
  # or ontology buckets. Deliberately mirrors ACTION-FOR-ACTION so the
  # next action added to the Allow can't silently escape.
  # NOTE: sources_data bucket is intentionally NOT in the deny list —
  # the SourcesDataBucketReadWrite statement above depends on it.
  statement {
    sid    = "DenyPlatformOwnedBuckets"
    effect = "Deny"
    actions = [
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:ListBucket",
      "s3:GetBucketTagging",
    ]
    resources = [
      var.athena_results_bucket_arn,
      "${var.athena_results_bucket_arn}/*",
      var.athena_spill_bucket_arn,
      "${var.athena_spill_bucket_arn}/*",
      var.ontology_bucket_arn,
      "${var.ontology_bucket_arn}/*",
    ]
  }

  # sts:AssumeRole for customer-supplied cross-account roles that the
  # customer created following the platform prefix naming convention.
  statement {
    sid       = "AssumeRoleCustomerProvided"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:${data.aws_partition.current.partition}:iam::*:role/${var.resource_prefix}-*"]
  }

  # Textract for scanned-PDF OCR + tables path.
  statement {
    sid       = "Textract"
    actions   = ["textract:DetectDocumentText", "textract:AnalyzeDocument"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "preprocessing" {
  name   = "${var.name_prefix}-sources-doc-preprocessing-policy"
  policy = data.aws_iam_policy_document.preprocessing.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "preprocessing" {
  role       = aws_iam_role.preprocessing.name
  policy_arn = aws_iam_policy.preprocessing.arn
}

# ═════════════════════════════════════════════════════════════════════
#  2. KG Build Task Role + Execution Role
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "kg_build_execution" {
  name               = "${var.name_prefix}-sources-doc-kg-build-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "kg_build_execution" {
  role       = aws_iam_role.kg_build_execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "kg_build_task" {
  name               = "${var.name_prefix}-sources-doc-kg-build-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
  tags               = local.tags
}

data "aws_iam_policy_document" "kg_build_task" {
  # Sources bucket read/write for staging artifacts.
  statement {
    sid = "SourcesBucketReadWrite"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket",
      "s3:AbortMultipartUpload",
    ]
    resources = [
      aws_s3_bucket.sources_data.arn,
      "${aws_s3_bucket.sources_data.arn}/*",
    ]
  }

  # Sources table for updating job status.
  statement {
    sid = "SourcesTableAccess"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "dynamodb:Query",
    ]
    resources = [
      aws_dynamodb_table.sources.arn,
      "${aws_dynamodb_table.sources.arn}/index/*",
    ]
  }

  # Neptune data-access (Gremlin/SPARQL).
  statement {
    sid = "NeptuneDataAccess"
    actions = [
      "neptune-db:ReadDataViaQuery",
      "neptune-db:WriteDataViaQuery",
      "neptune-db:DeleteDataViaQuery",
      "neptune-db:GetQueryStatus",
      "neptune-db:CancelQuery",
    ]
    resources = [var.neptune_cluster_arn]
  }

  statement {
    sid       = "AossApiAccess"
    actions   = ["aoss:APIAccessAll"]
    resources = [var.opensearch_collection_arn]
  }

  statement {
    sid     = "BedrockInvokeModel"
    actions = ["bedrock:InvokeModel"]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*",
      "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*",
    ]
  }

  # ApplyGuardrail for ingestion-time content screening.
  statement {
    sid     = "BedrockApplyGuardrail"
    actions = ["bedrock:ApplyGuardrail"]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:${var.region}:${data.aws_caller_identity.current.account_id}:guardrail/*",
    ]
  }

  # Guardrail decision metrics.
  statement {
    sid       = "CloudwatchGuardrailMetrics"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["COA/Guardrails"]
    }
  }

  # Bedrock batch inference — scoped to the same model ARNs as
  # InvokeModel above.
  statement {
    sid = "BedrockBatchInference"
    actions = [
      "bedrock:CreateModelInvocationJob",
      "bedrock:GetModelInvocationJob",
      "bedrock:ListModelInvocationJobs",
      "bedrock:StopModelInvocationJob",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*",
      "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*",
    ]
  }

  # Pass the batch inference role to Bedrock.
  statement {
    sid       = "PassBatchInferenceRole"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.batch_inference.arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["bedrock.amazonaws.com"]
    }
  }

  # SSM read for retrieval-guardrail id + version.
  statement {
    sid     = "GuardrailSsm"
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:${data.aws_partition.current.partition}:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_prefix}/bedrock/retrieval-guardrail-id",
      "arn:${data.aws_partition.current.partition}:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_prefix}/bedrock/retrieval-guardrail-version",
    ]
  }
}

resource "aws_iam_policy" "kg_build_task" {
  name   = "${var.name_prefix}-sources-doc-kg-build-task-policy"
  policy = data.aws_iam_policy_document.kg_build_task.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "kg_build_task" {
  role       = aws_iam_role.kg_build_task.name
  policy_arn = aws_iam_policy.kg_build_task.arn
}

# ═════════════════════════════════════════════════════════════════════
#  3. Bedrock Batch Inference role (service role for batch jobs)
# ═════════════════════════════════════════════════════════════════════
# Trusted by bedrock.amazonaws.com with SourceAccount + SourceArn
# conditions — the confused-deputy prevention pattern.

data "aws_iam_policy_document" "batch_inference_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.current.partition}:bedrock:${var.region}:${data.aws_caller_identity.current.account_id}:model-invocation-job/*"]
    }
  }
}

resource "aws_iam_role" "batch_inference" {
  name               = "${var.name_prefix}-sources-doc-bedrock-batch-inference"
  assume_role_policy = data.aws_iam_policy_document.batch_inference_trust.json
  tags               = local.tags
}

data "aws_iam_policy_document" "batch_inference" {
  statement {
    sid = "SourcesBucketReadWrite"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket",
      "s3:AbortMultipartUpload",
    ]
    resources = [
      aws_s3_bucket.sources_data.arn,
      "${aws_s3_bucket.sources_data.arn}/*",
    ]
  }

  statement {
    sid     = "BedrockInvokeModel"
    actions = ["bedrock:InvokeModel"]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*",
      "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*",
    ]
  }
}

resource "aws_iam_policy" "batch_inference" {
  name   = "${var.name_prefix}-sources-doc-bedrock-batch-inference-policy"
  policy = data.aws_iam_policy_document.batch_inference.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "batch_inference" {
  role       = aws_iam_role.batch_inference.name
  policy_arn = aws_iam_policy.batch_inference.arn
}

# ═════════════════════════════════════════════════════════════════════
#  4. Doc Cleanup Lambda role
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "doc_cleanup" {
  name               = "${var.name_prefix}-sources-doc-deletion-cleanup-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "doc_cleanup_vpc" {
  role       = aws_iam_role.doc_cleanup.name
  policy_arn = data.aws_iam_policy.lambda_vpc_access.arn
}

data "aws_iam_policy_document" "doc_cleanup" {
  statement {
    sid = "SourcesTableAccess"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "dynamodb:DeleteItem", "dynamodb:Query",
    ]
    resources = [
      aws_dynamodb_table.sources.arn,
      "${aws_dynamodb_table.sources.arn}/index/*",
    ]
  }

  # Read + delete on sources_data (S3 cleanup).
  statement {
    sid = "SourcesBucketReadDelete"
    actions = [
      "s3:GetObject", "s3:DeleteObject", "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.sources_data.arn,
      "${aws_s3_bucket.sources_data.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "doc_cleanup" {
  name   = "${var.name_prefix}-sources-doc-deletion-cleanup-policy"
  policy = data.aws_iam_policy_document.doc_cleanup.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "doc_cleanup" {
  role       = aws_iam_role.doc_cleanup.name
  policy_arn = aws_iam_policy.doc_cleanup.arn
}

# ═════════════════════════════════════════════════════════════════════
#  5. Doc Trigger Lambda role
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "doc_trigger" {
  name               = "${var.name_prefix}-sources-doc-ingestion-trigger-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "doc_trigger_vpc" {
  role       = aws_iam_role.doc_trigger.name
  policy_arn = data.aws_iam_policy.lambda_vpc_access.arn
}

data "aws_iam_policy_document" "doc_trigger" {
  statement {
    sid = "SqsPolling"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.doc_ingestion.arn]
  }

  statement {
    sid       = "StartStateMachine"
    actions   = ["states:StartExecution"]
    resources = [aws_sfn_state_machine.doc_ingestion.arn]
  }
}

resource "aws_iam_policy" "doc_trigger" {
  name   = "${var.name_prefix}-sources-doc-ingestion-trigger-policy"
  policy = data.aws_iam_policy_document.doc_trigger.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "doc_trigger" {
  role       = aws_iam_role.doc_trigger.name
  policy_arn = aws_iam_policy.doc_trigger.arn
}

# ═════════════════════════════════════════════════════════════════════
#  6. SFN role for docIngestion state machine
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "sfn_doc_ingestion" {
  name               = "${var.name_prefix}-sources-doc-ingestion-sfn"
  assume_role_policy = data.aws_iam_policy_document.sfn_db_scan_trust.json # same trust doc — states.amazonaws.com
  tags               = local.tags
}

data "aws_iam_policy_document" "sfn_doc_ingestion" {
  statement {
    actions = ["lambda:InvokeFunction"]
    resources = [
      aws_lambda_function.preprocessing.arn,
      "${aws_lambda_function.preprocessing.arn}:*",
    ]
  }

  statement {
    actions   = ["ecs:RunTask"]
    resources = [aws_ecs_task_definition.kg_build.arn]
  }

  statement {
    actions = ["ecs:StopTask", "ecs:DescribeTasks"]
    resources = [
      "arn:${data.aws_partition.current.partition}:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:task/*",
    ]
  }

  statement {
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.kg_build_task.arn,
      aws_iam_role.kg_build_execution.arn,
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    actions = [
      "events:PutTargets", "events:PutRule",
      "events:DescribeRule",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:events:${var.region}:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForECSTaskRule",
    ]
  }

  statement {
    actions = [
      "dynamodb:UpdateItem", "dynamodb:PutItem", "dynamodb:GetItem",
    ]
    resources = [aws_dynamodb_table.sources.arn]
  }

  statement {
    actions = [
      "xray:PutTraceSegments", "xray:PutTelemetryRecords",
      "xray:GetSamplingRules", "xray:GetSamplingTargets",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "sfn_doc_ingestion" {
  name   = "${var.name_prefix}-sources-doc-ingestion-sfn-policy"
  policy = data.aws_iam_policy_document.sfn_doc_ingestion.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "sfn_doc_ingestion" {
  role       = aws_iam_role.sfn_doc_ingestion.name
  policy_arn = aws_iam_policy.sfn_doc_ingestion.arn
}

# ═════════════════════════════════════════════════════════════════════
#  7. SFN role for docDeletion state machine
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "sfn_doc_deletion" {
  name               = "${var.name_prefix}-sources-doc-deletion-sfn"
  assume_role_policy = data.aws_iam_policy_document.sfn_db_scan_trust.json
  tags               = local.tags
}

data "aws_iam_policy_document" "sfn_doc_deletion" {
  statement {
    actions = ["lambda:InvokeFunction"]
    resources = [
      aws_lambda_function.doc_cleanup.arn,
      "${aws_lambda_function.doc_cleanup.arn}:*",
    ]
  }

  # Reuses the kg-build task def for graph-cleanup runs.
  statement {
    actions   = ["ecs:RunTask"]
    resources = [aws_ecs_task_definition.kg_build.arn]
  }

  statement {
    actions = ["ecs:StopTask", "ecs:DescribeTasks"]
    resources = [
      "arn:${data.aws_partition.current.partition}:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:task/*",
    ]
  }

  statement {
    actions = ["iam:PassRole"]
    resources = [
      aws_iam_role.kg_build_task.arn,
      aws_iam_role.kg_build_execution.arn,
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  statement {
    actions = [
      "events:PutTargets", "events:PutRule",
      "events:DescribeRule",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:events:${var.region}:${data.aws_caller_identity.current.account_id}:rule/StepFunctionsGetEventsForECSTaskRule",
    ]
  }

  # docDeleteDdbRecord state deletes an item.
  statement {
    actions = [
      "dynamodb:DeleteItem", "dynamodb:UpdateItem", "dynamodb:GetItem",
    ]
    resources = [aws_dynamodb_table.sources.arn]
  }

  statement {
    actions = [
      "xray:PutTraceSegments", "xray:PutTelemetryRecords",
      "xray:GetSamplingRules", "xray:GetSamplingTargets",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "sfn_doc_deletion" {
  name   = "${var.name_prefix}-sources-doc-deletion-sfn-policy"
  policy = data.aws_iam_policy_document.sfn_doc_deletion.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "sfn_doc_deletion" {
  role       = aws_iam_role.sfn_doc_deletion.name
  policy_arn = aws_iam_policy.sfn_doc_deletion.arn
}
