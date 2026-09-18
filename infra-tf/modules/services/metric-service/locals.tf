# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  # ── Physical names (match CDK prefixed() outputs) ─────────────────
  import_jobs_table_name = "${var.name_prefix}-metric-import-jobs"
  import_queue_name      = "${var.name_prefix}-metric-import-queue"
  import_dlq_name        = "${var.name_prefix}-metric-import-dlq"
  osi_bucket_name        = "${var.name_prefix}-metric-osi-${data.aws_caller_identity.current.account_id}"
  osi_logs_bucket_name   = "${var.name_prefix}-metric-logs-${data.aws_caller_identity.current.account_id}"

  # ── Lambda function names ─────────────────────────────────────────
  fn_metric_api    = "${var.name_prefix}-metric-api"
  fn_import_worker = "${var.name_prefix}-metric-import-worker"

  # ── Common tags ────────────────────────────────────────────────────
  tags = {
    Component = var.component
  }

  # ── Deterministic zip content hash ─────────────────────────────────
  # Triggers Lambda redeploy when the Makefile rebuilds the zip. `try`
  # keeps `terraform validate`/`plan` working before the zip is built —
  # a missing file yields a null hash (no forced update) instead of a
  # hard error.
  lambda_zip_hash = try(filebase64sha256(var.metric_service_zip_path), null)

  # ── Bedrock model ARN (matches bedrockModelArn util) ───────────────
  # A geographic inference profile carries a leading geo segment, so it
  # has >= 3 dot-separated segments (us.cohere.embed-v4:0); a bare
  # foundation-model id has 2 (cohere.embed-v4:0). The CDK builds the
  # grant with region "*" and the current account, PLUS a wildcard
  # foundation-model ARN for the models an inference profile fans out to.
  bedrock_is_inference_profile = length(split(".", var.bedrock_embed_model_id)) >= 3
  bedrock_model_arn = local.bedrock_is_inference_profile ? (
    "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/${var.bedrock_embed_model_id}"
    ) : (
    "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/${var.bedrock_embed_model_id}"
  )
  bedrock_invoke_resources = [
    local.bedrock_model_arn,
    "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*",
  ]

  # ── SMUS catalog table ARNs ────────────────────────────────────────
  # The CDK resolves these via Table.fromTableName + grantReadData,
  # which scopes to the table and all its indexes.
  sources_table_arn    = "arn:${data.aws_partition.current.partition}:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.sources_table_name}"
  namespaces_table_arn = "arn:${data.aws_partition.current.partition}:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.namespaces_table_name}"

  # ── SMUS catalog env fragment ──────────────────────────────────────
  # Only inject the SMUS domain / project-access-role vars when the
  # caller supplies them (matches CDK, which always sets them from SSM
  # but here they are optional module inputs).
  smus_env = merge(
    var.smus_domain_id != null ? { SMUS_DOMAIN_ID = var.smus_domain_id } : {},
    var.smus_project_access_role_arn != null ? { PROJECT_ACCESS_ROLE_ARN = var.smus_project_access_role_arn } : {},
  )

  # ── Shared Lambda environment ──────────────────────────────────────
  # Common vars set on both the API and worker Lambdas. Function-specific
  # vars are merged on top at each aws_lambda_function.
  common_env = merge(
    {
      NEPTUNE_ENDPOINT = "https://${var.neptune_endpoint}:8182"
      # Same base URI serve reads from. Both writers (this module,
      # ontology-engine) and readers (serve) must resolve to the same
      # value or metric writes and reads see different named graphs —
      # the CDK DEFAULT_GRAPH_URI_BASE consolidation. Sourced from
      # local.brand_env at the root so a single change flows to every
      # module that reads GRAPH_BASE_URI.
      NDB_GRAPH_URI_BASE  = var.brand_env.GRAPH_BASE_URI
      OPENSEARCH_ENDPOINT = var.opensearch_endpoint
      OSS_INDEX_PREFIX    = var.opensearch_collection_name
      BEDROCK_MODEL_ID    = var.bedrock_embed_model_id
      BEDROCK_REGION      = var.region
      OSI_BUCKET_NAME     = aws_s3_bucket.osi.bucket
      DATA_SOURCES_TABLE  = var.sources_table_name
      NAMESPACES_TABLE    = var.namespaces_table_name
    },
    local.smus_env,
  )

  metric_api_env = merge(
    local.common_env,
    {
      EVENTBRIDGE_BUS_NAME = var.event_bus_name
      ALLOWED_ORIGIN       = var.allowed_origin
      IMPORT_QUEUE_URL     = aws_sqs_queue.import.url
      IMPORT_JOBS_TABLE    = aws_dynamodb_table.import_jobs.name
    },
  )

  import_worker_env = merge(
    local.common_env,
    {
      IMPORT_QUEUE_URL  = aws_sqs_queue.import.url
      IMPORT_JOBS_TABLE = aws_dynamodb_table.import_jobs.name
    },
  )
}
