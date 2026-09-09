# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Stack 10 — Foundation services (storage, authnz, guardrail, auth-idp,
# edge-waf). Depends on 00-network via SSM. Publishes all downstream
# handoff via module-owned SSM writes plus a few stack-added entries.

module "storage" {
  source = "../../modules/foundation/storage"

  allowed_origin            = local.allowed_origin
  aoss_max_ocu              = var.aoss_max_ocu
  aoss_min_ocu              = var.aoss_min_ocu
  aoss_security_group_id    = local.aoss_security_group_id
  aoss_vpc_endpoint_id      = local.aoss_vpc_endpoint_id
  env                       = var.env
  name_prefix               = local.name_prefix
  neptune_security_group_id = local.neptune_security_group_id
  private_subnet_ids        = local.private_subnet_ids
  region                    = var.region
  ssm_prefix                = local.ssm_prefix
}

module "authnz" {
  source = "../../modules/foundation/authnz"

  cedar_seed_path = "${path.root}/../../../libs/common/src/coa_authorization/seed"
  claims_mappings = var.initial_claims_mappings
  environment     = var.env
  name_prefix     = local.name_prefix
  ssm_prefix      = local.ssm_prefix
}

module "guardrail" {
  source = "../../modules/foundation/guardrail"

  name_prefix = local.name_prefix
  ssm_prefix  = local.ssm_prefix
}

module "auth_idp" {
  source = "../../modules/foundation/auth-idp"

  callback_urls                = var.callback_urls
  cognito_custom_attributes    = var.cognito_custom_attributes
  custom_domain_ui_domain_name = var.ui_domain_name
  idp_type                     = var.idp_type
  initial_admin_email          = var.initial_admin_email
  logout_urls                  = var.logout_urls
  name_prefix                  = local.name_prefix
  oidc_providers               = var.oidc_providers
  oidc_settings                = var.oidc_settings
  refresh_token_validity_hours = var.refresh_token_validity_hours
  saml_providers               = var.saml_providers
  ssm_prefix                   = local.ssm_prefix
}

module "edge_waf" {
  source    = "../../modules/foundation/edge-waf"
  providers = { aws = aws.us_east_1 }

  name_prefix             = local.name_prefix
  ssm_prefix              = local.ssm_prefix
  waf_rate_limit_per_5min = 2000
}

# ── Stack-added SSM writes for downstream consumers ──────────────────
# Storage module already writes all its outputs to SSM. auth-idp writes
# user_pool_id/userpool_client_id/mcp_client_id/issuer/group_token_name.
# authnz writes roles_table_name/resource_role_mappings_table_name/
# cache_invalidation_table_name. Guardrail writes guardrail_id/version
# + retrieval_guardrail_id/version. Everything downstream needs is
# already there — additions below are ARNs (modules write names only).

resource "aws_ssm_parameter" "roles_table_arn" {
  name  = "${local.ssm_prefix}/authnz/roles-table-arn"
  type  = "String"
  value = module.authnz.roles_table_arn
}

resource "aws_ssm_parameter" "roles_table_stream_arn" {
  name  = "${local.ssm_prefix}/authnz/roles-table-stream-arn"
  type  = "String"
  value = module.authnz.roles_table_stream_arn
}

resource "aws_ssm_parameter" "resource_role_mappings_table_arn" {
  name  = "${local.ssm_prefix}/authnz/resource-role-mappings-table-arn"
  type  = "String"
  value = module.authnz.resource_role_mappings_table_arn
}

resource "aws_ssm_parameter" "resource_role_mappings_table_stream_arn" {
  name  = "${local.ssm_prefix}/authnz/resource-role-mappings-table-stream-arn"
  type  = "String"
  value = module.authnz.resource_role_mappings_table_stream_arn
}

resource "aws_ssm_parameter" "cache_invalidation_table_arn" {
  name  = "${local.ssm_prefix}/authnz/cache-invalidation-table-arn"
  type  = "String"
  value = module.authnz.cache_invalidation_table_arn
}

resource "aws_ssm_parameter" "ontology_bucket_arn" {
  name  = "${local.ssm_prefix}/storage/ontology-bucket-arn"
  type  = "String"
  value = module.storage.ontology_artifacts_bucket_arn
}

resource "aws_ssm_parameter" "opensearch_collection_arn" {
  name  = "${local.ssm_prefix}/storage/opensearch-collection-arn"
  type  = "String"
  value = module.storage.opensearch_collection_arn
}

resource "aws_ssm_parameter" "neptune_cluster_arn_full" {
  name  = "${local.ssm_prefix}/storage/neptune-cluster-arn-full"
  type  = "String"
  value = module.storage.neptune_cluster_arn
}

resource "aws_ssm_parameter" "athena_results_bucket_name" {
  name  = "${local.ssm_prefix}/storage/athena-results-bucket-name"
  type  = "String"
  value = module.storage.athena_results_bucket_name
}

resource "aws_ssm_parameter" "athena_results_bucket_arn" {
  name  = "${local.ssm_prefix}/storage/athena-results-bucket-arn"
  type  = "String"
  value = module.storage.athena_results_bucket_arn
}

resource "aws_ssm_parameter" "athena_spill_bucket_name" {
  name  = "${local.ssm_prefix}/storage/athena-spill-bucket-name"
  type  = "String"
  value = module.storage.athena_spill_bucket_name
}

resource "aws_ssm_parameter" "athena_spill_bucket_arn" {
  name  = "${local.ssm_prefix}/storage/athena-spill-bucket-arn"
  type  = "String"
  value = module.storage.athena_spill_bucket_arn
}
