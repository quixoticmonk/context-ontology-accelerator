# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Stack 50 — AgentCore (serve + mcp). Depends on all prior stacks (00-40).
# Publishes /coa/serve/runtime-arn for consumers 55-data-layer + 60-api-edge.

module "serve" {
  source = "../../modules/services/serve"

  agentcore_az_names                = local.agentcore_az_names
  allowed_override_models           = var.allowed_override_models
  aoss_proxy_zip_path               = "${path.root}/../../artifacts/lambdas/aoss-proxy.zip"
  aoss_security_group_id            = local.aoss_security_group_id
  aoss_vpc_endpoint_id              = local.aoss_vpc_endpoint_id
  athena_results_bucket_name        = local.athena_results_bucket_name
  athena_spill_bucket_name          = local.athena_spill_bucket_name
  bedrock_embed_model_id            = var.bedrock_embed_model_id
  bedrock_llm_model_id              = var.bedrock_llm_model_id
  brand_env                         = local.brand_env
  connector_spill_kms_tag_key       = "${var.resource_prefix}:connector-spill"
  connector_tag_key                 = "${var.resource_prefix}:connector"
  ecr_repository_arn                = local.context_manager_ecr_repository_arn
  ecr_repository_url                = local.context_manager_ecr_repository_url
  image_tag_file                    = "${path.root}/../../artifacts/images/context-manager.tag"
  env                               = var.env
  group_claim_name                  = local.group_claim_name
  issuer_url                        = local.issuer_url
  lambda_security_group_id          = local.lambda_security_group_id
  mcp_client_id                     = local.mcp_client_id
  name_prefix                       = local.name_prefix
  namespace_tag_key                 = "${var.resource_prefix}:namespace"
  namespaces_table_arn              = local.namespaces_table_arn
  namespaces_table_name             = local.namespaces_table_name
  neptune_cluster_arn               = local.neptune_cluster_arn
  neptune_endpoint                  = local.neptune_endpoint
  ontology_bucket_arn               = local.ontology_bucket_arn
  opensearch_collection_arn         = local.opensearch_collection_arn
  opensearch_collection_name        = local.opensearch_collection_name
  opensearch_endpoint               = local.opensearch_endpoint
  private_subnet_ids                = local.private_subnet_ids
  region                            = var.region
  resource_prefix                   = var.resource_prefix
  resource_role_mappings_table_arn  = local.resource_role_mappings_table_arn
  resource_role_mappings_table_name = local.resource_role_mappings_table_name
  roles_table_arn                   = local.roles_table_arn
  roles_table_name                  = local.roles_table_name
  sources_table_name                = local.sources_table_name
  ssm_prefix                        = local.ssm_prefix
  userpool_client_id                = local.userpool_client_id
  vkg_endpoint                      = ""
  vpc_cidr                          = local.vpc_cidr
  vpc_id                            = local.vpc_id
}

module "mcp" {
  source = "../../modules/services/mcp"

  agentcore_az_names                = local.agentcore_az_names
  brand_env                         = local.brand_env
  cm_runtime_arn                    = module.serve.agent_runtime_arn
  ecr_repository_arn                = local.mcp_server_ecr_repository_arn
  ecr_repository_url                = local.mcp_server_ecr_repository_url
  image_tag_file                    = "${path.root}/../../artifacts/images/mcp-server.tag"
  env                               = var.env
  group_claim_name                  = local.group_claim_name
  issuer_url                        = local.issuer_url
  mcp_client_id                     = local.mcp_client_id
  metric_service_lambda_arn         = local.metric_service_lambda_arn
  name_prefix                       = local.name_prefix
  ontology_proxy_lambda_arn         = local.ontology_proxy_lambda_arn
  private_subnet_ids                = local.private_subnet_ids
  region                            = var.region
  resource_role_mappings_table_arn  = local.resource_role_mappings_table_arn
  resource_role_mappings_table_name = local.resource_role_mappings_table_name
  roles_table_arn                   = local.roles_table_arn
  roles_table_name                  = local.roles_table_name
  ssm_prefix                        = local.ssm_prefix
  userpool_client_id                = local.userpool_client_id
  vpc_cidr                          = local.vpc_cidr
  vpc_id                            = local.vpc_id
}

# ── Stack-added SSM writes ───────────────────────────────────────────
# Serve module already writes serve/runtime-arn, runtime-role-arn,
# aoss-proxy-lambda-arn. Add aoss-proxy-fn-arn for observability lookup.

resource "aws_ssm_parameter" "aoss_proxy_fn_arn" {
  name  = "${local.ssm_prefix}/serve/aoss-proxy-fn-arn"
  type  = "String"
  value = module.serve.aoss_proxy_fn_arn
}
