# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Database pipeline compute: 5 Lambdas + 1 Fargate task definition.
# All Lambda source_code_hash values wrap filebase64sha256 in try(...)
# so plan doesn't fail before the zips are built.

locals {
  sources_zip_hash        = try(filebase64sha256(var.sources_zip_path), null)
  sources_db_trigger_hash = try(filebase64sha256(var.sources_db_trigger_zip_path), null)

  # Bedrock model ARN — matches infra/lib/utils/bedrock-utils.ts logic.
  # For a `us.` cross-region inference profile (>= 3 dot segments), emit
  # the inference-profile ARN. For a bare in-region model id, emit the
  # foundation-model ARN. Passed to the enrichment container as
  # BEDROCK_MODEL_ARN so the container calls the right endpoint.
  bedrock_model_arn = (
    length(split(".", var.bedrock_chat_model_id)) >= 3
    ? "arn:${data.aws_partition.current.partition}:bedrock:${var.region}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.bedrock_chat_model_id}"
    : "arn:${data.aws_partition.current.partition}:bedrock:${var.region}::foundation-model/${var.bedrock_chat_model_id}"
  )

  db_enrichment_image_uri = (
    var.db_enrichment_image_tag_file != null
    ? trimspace(file(var.db_enrichment_image_tag_file))
    : "${var.db_enrichment_ecr_repository_url}:latest"
  )
}

# ═════════════════════════════════════════════════════════════════════
#  1. DB Connector Lambda (discovery)
# ═════════════════════════════════════════════════════════════════════

resource "aws_lambda_function" "db_connector" {
  function_name    = "${var.name_prefix}-sources-db-connector"
  role             = aws_iam_role.db_connector.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "coa_sources.database.pipeline.discovery_handler.handler"
  filename         = var.sources_zip_path
  source_code_hash = local.sources_zip_hash
  timeout          = 900
  memory_size      = 1024

  vpc_config {
    subnet_ids = var.private_subnet_ids
    # Dedicated OCSP SG (from network module) piggybacks on the shared
    # lambda SG so the Snowflake driver can reach port-80 OCSP responders
    # without leaking that egress path to every other platform Lambda.
    security_group_ids = [var.lambda_security_group_id, var.discovery_ocsp_security_group_id]
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.db_connector_dlq.arn
  }

  environment {
    variables = {
      SOURCES_TABLE              = aws_dynamodb_table.sources.name
      SOURCE_SCAN_JOBS_TABLE     = aws_dynamodb_table.source_scan_jobs.name
      NAMESPACES_TABLE           = var.namespaces_table_name
      SMUS_DOMAIN_ID             = var.smus_domain_id
      PROJECT_ACCESS_ROLE_ARN    = var.smus_project_access_role_arn
      RESOURCE_TAG_PREFIX        = var.resource_prefix
      DATAZONE_WRITE_PARALLELISM = "10"
      MAX_TABLES_PER_SOURCE      = "10000"
      ATHENA_SPILL_BUCKET        = var.athena_spill_bucket_name
      RESOURCE_PREFIX            = "${var.name_prefix}-"
      # Re-scan backup blob (pre-rescan asset forms + change-set) is
      # written here before a merge overwrites live assets, and read
      # back by the bulk-review worker on approve/reject. Same bucket
      # as the API/worker.
      BUCKET_NAME         = aws_s3_bucket.sources_data.bucket
      LF_GRANTOR_ROLE_ARN = aws_iam_role.federation_provisioner.arn
      # CONSUMER_QUERY_ROLE_ARN wired in sub-turn 4 when the serve
      # module's SSM param is guaranteed present at deploy order.
    }
  }

  tags = local.tags
}

# The Lambda-native DLQ requires SendMessage permission on the DLQ.
resource "aws_sqs_queue_policy" "db_connector_dlq" {
  queue_url = aws_sqs_queue.db_connector_dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = aws_iam_role.db_connector.arn }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.db_connector_dlq.arn
    }]
  })
}

# ═════════════════════════════════════════════════════════════════════
#  2. Federation Provisioner Lambda (JDBC-only, dedicated LF admin)
# ═════════════════════════════════════════════════════════════════════

resource "aws_lambda_function" "federation_provisioner" {
  function_name    = "${var.name_prefix}-sources-federation-provisioner"
  role             = aws_iam_role.federation_provisioner.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "coa_sources.database.pipeline.federation_handler.handler"
  filename         = var.sources_zip_path
  source_code_hash = local.sources_zip_hash
  timeout          = 300
  memory_size      = 512

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      SOURCES_TABLE               = aws_dynamodb_table.sources.name
      CONNECTOR_SECURITY_GROUP_ID = var.connector_security_group_id
      # Glue Connections accept one SubnetId — single-AZ per federated
      # query; multi-AZ resilience is future work.
      CONNECTOR_SUBNET_ID           = var.private_subnet_ids[0]
      RESOURCE_PREFIX               = "${var.name_prefix}-"
      ATHENA_SPILL_BUCKET           = var.athena_spill_bucket_name
      FEDERATED_CATALOG_ROLE_ARN    = aws_iam_role.federated_catalog.arn
      CONSUMER_QUERY_ROLE_SSM_PARAM = "${var.ssm_prefix}/serve/runtime-role-arn"
      RESOURCE_TAG_PREFIX           = var.resource_prefix
    }
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  3. DB Enrichment Task Definition (Fargate)
# ═════════════════════════════════════════════════════════════════════

resource "aws_ecs_task_definition" "db_enrichment" {
  family                   = "${var.name_prefix}-sources-db-enrichment-agent"
  cpu                      = "2048"
  memory                   = "8192"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.db_enrichment_execution.arn
  task_role_arn            = aws_iam_role.db_enrichment_task.arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([{
    name  = "${var.name_prefix}-sources-db-enrichment-agent"
    image = local.db_enrichment_image_uri

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.db_enrichment.name
        "awslogs-region"        = var.region
        "awslogs-stream-prefix" = "sources-db-enrichment"
      }
    }

    environment = [
      { name = "SOURCES_TABLE", value = aws_dynamodb_table.sources.name },
      { name = "SOURCE_SCAN_JOBS_TABLE", value = aws_dynamodb_table.source_scan_jobs.name },
      { name = "NAMESPACES_TABLE", value = var.namespaces_table_name },
      { name = "SMUS_DOMAIN_ID", value = var.smus_domain_id },
      { name = "PROJECT_ACCESS_ROLE_ARN", value = var.smus_project_access_role_arn },
      # ECS does not inject a region — resolve_region() otherwise falls
      # back to us-east-1 and Bedrock calls target the wrong region.
      { name = "AWS_DEFAULT_REGION", value = var.region },
      { name = "BEDROCK_REGION", value = var.region },
      # Without this the enrichment task's Bedrock calls run UNGUARDED —
      # table_enricher._resolve_guardrail_id() reads this param name to
      # look up the guardrail id. Same param the doc pipeline reads
      # (#111 AC5). The `retrieval-guardrail-id` SSM parameter is created
      # by modules/foundation/guardrail alongside the older
      # `guardrail-id` param.
      { name = "GUARDRAIL_SSM_PARAM", value = "${var.ssm_prefix}/bedrock/retrieval-guardrail-id" },
      { name = "BEDROCK_CHAT_MODEL_ID", value = var.bedrock_chat_model_id },
    ]
  }])

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  4. DB Scan Reaper Lambda (terminal-status safety net)
# ═════════════════════════════════════════════════════════════════════

resource "aws_lambda_function" "db_scan_reaper" {
  function_name    = "${var.name_prefix}-sources-db-scan-reaper"
  role             = aws_iam_role.db_scan_reaper.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "coa_sources.database.pipeline.reaper_handler.handler"
  filename         = var.sources_zip_path
  source_code_hash = local.sources_zip_hash
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      SOURCES_TABLE = aws_dynamodb_table.sources.name
    }
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  5. DB Scan Trigger Lambda (SQS → SFN)
# ═════════════════════════════════════════════════════════════════════
# Small stand-alone bundle — packages/sources/database/trigger only.

resource "aws_lambda_function" "db_scan_trigger" {
  function_name    = "${var.name_prefix}-sources-db-scan-trigger"
  role             = aws_iam_role.db_scan_trigger.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  filename         = var.sources_db_trigger_zip_path
  source_code_hash = local.sources_db_trigger_hash
  timeout          = 30
  memory_size      = 128

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      STATE_MACHINE_ARN = aws_sfn_state_machine.db_scan.arn
    }
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  6. Bulk Review Worker Lambda
# ═════════════════════════════════════════════════════════════════════

resource "aws_lambda_function" "bulk_review_worker" {
  function_name    = "${var.name_prefix}-sources-bulk-review-worker"
  role             = aws_iam_role.bulk_review_worker.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "index.handler"
  filename         = var.sources_zip_path
  source_code_hash = local.sources_zip_hash
  timeout          = 300
  memory_size      = 512

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      SOURCES_TABLE = aws_dynamodb_table.sources.name
      # Scan-history store — the worker appends a REVIEW audit row here
      # on each terminal approve/reject so the console shows real
      # history.
      SOURCE_SCAN_JOBS_TABLE  = aws_dynamodb_table.source_scan_jobs.name
      NAMESPACES_TABLE        = var.namespaces_table_name
      SMUS_DOMAIN_ID          = var.smus_domain_id
      PROJECT_ACCESS_ROLE_ARN = var.smus_project_access_role_arn
      BULK_REVIEW_PARALLELISM = "10"
      REVIEW_QUEUE_URL        = aws_sqs_queue.bulk_review.url
      # Re-scan finalize: the worker reads the pre-rescan backup blob
      # to delete removed items (approve) or restore the pre-rescan
      # state (reject). Same bucket discovery wrote the backup to.
      BUCKET_NAME = aws_s3_bucket.sources_data.bucket
    }
  }

  tags = local.tags
}
