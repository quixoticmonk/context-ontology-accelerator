# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Optionally filter subnets by AgentCore-supported AZs.
data "aws_subnet" "private" {
  for_each = toset(var.private_subnet_ids)
  id       = each.value
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  tags       = { Component = var.component }

  runtime_name    = replace("${var.name_prefix}-context-manager", "-", "_")
  aoss_proxy_name = "${var.name_prefix}-aoss-search-proxy"

  # AgentCore rejects hyphens in runtime names.
  runtime_subnet_ids = (
    var.agentcore_az_names != null
    ? [for id, s in data.aws_subnet.private : id if contains(var.agentcore_az_names, s.availability_zone)]
    : var.private_subnet_ids
  )

  # Federated Glue catalog prefix (matches CDK `${prefix}-${env}` sanitized).
  federated_catalog_prefix = "${lower(replace(var.name_prefix, "/[^a-z0-9]/", ""))}ds_"

  image_uri = (
    var.image_tag_file != null
    ? trimspace(file(var.image_tag_file))
    : "${var.ecr_repository_url}:latest"
  )

  aoss_proxy_zip_hash = try(filebase64sha256(var.aoss_proxy_zip_path), null)

  # Environment variables for the AgentCore Runtime container.
  runtime_env = merge(var.brand_env, {
    ENVIRONMENT                        = var.env
    SSM_PREFIX                         = var.ssm_prefix
    LOG_LEVEL                          = "INFO"
    AWS_REGION                         = var.region
    NEPTUNE_ENDPOINT                   = var.neptune_endpoint
    VKG_ENDPOINT                       = var.vkg_endpoint
    OPENSEARCH_ENDPOINT                = var.opensearch_endpoint
    OPENSEARCH_PROXY_LAMBDA_ARN        = aws_lambda_function.aoss_proxy.arn
    ATHENA_OUTPUT_S3                   = "s3://${var.athena_results_bucket_name}/"
    ATHENA_WORKGROUP_PREFIX            = "${var.name_prefix}-"
    REDSHIFT_SERVE_DATABASE            = "dev"
    OSS_ONTOLOGY_INDEX                 = var.opensearch_collection_name
    TIER3_STRATEGY                     = "lexical-baseline"
    LEXICAL_RETRIEVER_STRATEGY         = "topic_beam"
    DEEP_REASONING_TIME_BUDGET_S       = "110"
    DEEP_REASONING_PER_TOOL_TIMEOUT_S  = "45"
    DEEP_REASONING_SYNTHESIS_RESERVE_S = "25"
    RESOLVE_TIMEOUT_S                  = "170"
    ALLOW_NO_GUARDRAIL                 = var.env != "prod" ? "true" : "false"
    GRAPH_URI_TEMPLATE                 = "https://ontology-workbench.local/{namespace}"
    DATA_SOURCES_TABLE                 = var.sources_table_name
    NAMESPACES_TABLE                   = var.namespaces_table_name
    ROLES_TABLE_NAME                   = var.roles_table_name
    RRM_TABLE_NAME                     = var.resource_role_mappings_table_name
    GROUP_CLAIM_NAME                   = var.group_claim_name
    MEMORY_ID                          = aws_bedrockagentcore_memory.session.id
    SESSION_METADATA_TABLE             = aws_dynamodb_table.session_metadata.name
    SCL_CEDAR_FAIL_OPEN_NO_ROLES       = "false"
    BEDROCK_MODEL_ID                   = var.bedrock_llm_model_id
    BEDROCK_EMBED_MODEL_ID             = var.bedrock_embed_model_id
    ALLOWED_OVERRIDE_MODELS            = join(",", var.allowed_override_models)
  })
}
