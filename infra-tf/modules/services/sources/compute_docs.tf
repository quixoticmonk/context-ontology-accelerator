# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Documents pipeline compute: preprocessing DockerImageFunction,
# kg-build Fargate task, doc-cleanup Lambda, doc-trigger Lambda.

locals {
  sources_doc_trigger_hash = try(filebase64sha256(var.sources_doc_trigger_zip_path), null)
  sources_doc_cleanup_hash = try(filebase64sha256(var.sources_doc_cleanup_zip_path), null)

  preprocessing_image_uri = (
    var.preprocessing_image_tag_file != null
    ? trimspace(file(var.preprocessing_image_tag_file))
    : "${var.preprocessing_ecr_repository_url}:latest"
  )

  kg_build_image_uri = (
    var.kg_build_image_tag_file != null
    ? trimspace(file(var.kg_build_image_tag_file))
    : "${var.kg_build_ecr_repository_url}:latest"
  )

  preprocessing_reserved_concurrency = var.lambda_reserved_concurrency > 0 ? var.lambda_reserved_concurrency : null
}

# ═════════════════════════════════════════════════════════════════════
#  1. Preprocessing DockerImageFunction
# ═════════════════════════════════════════════════════════════════════
# Docker image function → no runtime/handler/filename — uses `image_uri`.

resource "aws_lambda_function" "preprocessing" {
  function_name = "${var.name_prefix}-sources-doc-preprocessing"
  role          = aws_iam_role.preprocessing.arn
  package_type  = "Image"
  image_uri     = local.preprocessing_image_uri
  timeout       = 900
  memory_size   = 3008

  reserved_concurrent_executions = local.preprocessing_reserved_concurrency

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      BUCKET_NAME               = aws_s3_bucket.sources_data.bucket
      DOC_SOURCES_TABLE         = aws_dynamodb_table.sources.name
      MAX_FILE_SIZE_MB          = "200"
      CROSS_ACCOUNT_ROLE_PREFIX = var.resource_prefix
      RESOURCE_TAG_PREFIX       = var.resource_prefix
    }
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  2. KG Build Fargate task definition
# ═════════════════════════════════════════════════════════════════════
# 4 vCPU / 16 GB. Container Insights enabled on the cluster (ecs.tf).
# Environment variables that vary per invocation (DOC_SOURCE_ID,
# NAMESPACE_ID, STAGING_PREFIX, EXTRACTION_MODE, ...) are injected by
# the state machine's ContainerOverrides at RunTask time.

resource "aws_ecs_task_definition" "kg_build" {
  family                   = "${var.name_prefix}-sources-doc-kg-build"
  cpu                      = "4096"
  memory                   = "16384"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.kg_build_execution.arn
  task_role_arn            = aws_iam_role.kg_build_task.arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([{
    name  = "${var.name_prefix}-sources-doc-kg-build"
    image = local.kg_build_image_uri

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.kg_build.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "sources-doc-kg-build"
      }
    }

    environment = [
      { name = "BUCKET_NAME", value = aws_s3_bucket.sources_data.bucket },
      { name = "DOC_SOURCES_TABLE", value = aws_dynamodb_table.sources.name },
      { name = "NEPTUNE_ENDPOINT", value = var.neptune_endpoint },
      { name = "OPENSEARCH_ENDPOINT", value = var.opensearch_endpoint },
      { name = "BATCH_INFERENCE_ROLE_ARN", value = aws_iam_role.batch_inference.arn },
      # ECS does not inject a region — the container's Bedrock calls
      # would otherwise fall back to us-east-1.
      { name = "AWS_DEFAULT_REGION", value = var.region },
      { name = "BEDROCK_REGION", value = var.region },
      { name = "BEDROCK_EMBED_MODEL_ID", value = var.bedrock_embed_model_id },
      { name = "BEDROCK_EMBED_DIMENSIONS", value = tostring(var.bedrock_embed_dimensions) },
      { name = "BEDROCK_CHAT_MODEL_ID", value = var.bedrock_chat_model_id },
      # Retrieval guardrail — read from SSM at container start via the
      # container's SSM client using the two env vars below. CDK reads
      # via valueForStringParameter; TF passes the RESOLVED SSM values.
      # Since these SSM params are written by the guardrail module, we
      # inject the SSM PARAM NAMES here (the container reads them at
      # start). Sub-turn 4 wires the real values from ssm_prefix.
      { name = "RETRIEVAL_GUARDRAIL_ID_SSM_PARAM", value = "${var.ssm_prefix}/bedrock/retrieval-guardrail-id" },
      { name = "RETRIEVAL_GUARDRAIL_VERSION_SSM_PARAM", value = "${var.ssm_prefix}/bedrock/retrieval-guardrail-version" },
      { name = "BUILD_BATCH_WRITE_SIZE", value = "5" },
      { name = "EXTRACTION_NUM_WORKERS", value = "4" },
      { name = "BUILD_NUM_WORKERS", value = "4" },
      { name = "DEPENDENCY_LOG_LEVEL", value = "INFO" },
    ]
  }])

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  3. Doc Cleanup Lambda (S3 + DDB cleanup on deletion)
# ═════════════════════════════════════════════════════════════════════

resource "aws_lambda_function" "doc_cleanup" {
  function_name    = "${var.name_prefix}-sources-doc-deletion-cleanup"
  role             = aws_iam_role.doc_cleanup.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "cleanup_handler.handler"
  filename         = var.sources_doc_cleanup_zip_path
  source_code_hash = local.sources_doc_cleanup_hash
  timeout          = 300
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      DOC_SOURCES_TABLE = aws_dynamodb_table.sources.name
    }
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  4. Doc Trigger Lambda (SQS → docIngestion SFN)
# ═════════════════════════════════════════════════════════════════════
# Bundled with packages/sources/documents/trigger source. The
# BEDROCK_MODEL_ARN env var is pre-computed from the resolved chat
# model ID (matches bedrockModelArn in the CDK).

resource "aws_lambda_function" "doc_trigger" {
  function_name    = "${var.name_prefix}-sources-doc-ingestion-trigger"
  role             = aws_iam_role.doc_trigger.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "index.handler"
  filename         = var.sources_doc_trigger_zip_path
  source_code_hash = local.sources_doc_trigger_hash
  timeout          = 30
  memory_size      = 128

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      STATE_MACHINE_ARN = aws_sfn_state_machine.doc_ingestion.arn
      BEDROCK_MODEL_ARN = local.bedrock_model_arn
    }
  }

  tags = local.tags
}
