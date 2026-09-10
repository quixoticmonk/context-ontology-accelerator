# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  name_prefix = "${var.resource_prefix}-${var.env}"
  ssm_prefix  = "/${var.resource_prefix}"

  common_tags = {
    Environment = var.env
    ManagedBy   = "Terraform"
    Project     = var.project_tag
  }

  custom_domain_fields = {
    ui_domain_name      = var.ui_domain_name
    ui_certificate_arn  = var.ui_certificate_arn
    api_domain_name     = var.api_domain_name
    api_certificate_arn = var.api_certificate_arn
    hosted_zone_id      = var.hosted_zone_id
  }
  custom_domain_enabled = length([for v in values(local.custom_domain_fields) : v if v != null]) == length(local.custom_domain_fields)
  allowed_origin        = local.custom_domain_enabled ? "https://${var.ui_domain_name}" : "*"
  custom_domain = local.custom_domain_enabled ? {
    ui_domain_name      = var.ui_domain_name
    ui_certificate_arn  = var.ui_certificate_arn
    api_domain_name     = var.api_domain_name
    api_certificate_arn = var.api_certificate_arn
    hosted_zone_id      = var.hosted_zone_id
  } : null

  # Network handoff
  vpc_id                   = data.aws_ssm_parameter.vpc_id.value
  private_subnet_ids       = nonsensitive(split(",", data.aws_ssm_parameter.private_subnet_ids.value))
  lambda_security_group_id = data.aws_ssm_parameter.lambda_security_group_id.value

  # AuthNZ handoff (ARNs)
  cache_invalidation_table_arn            = data.aws_ssm_parameter.cache_invalidation_table_arn.value
  cache_invalidation_table_name           = data.aws_ssm_parameter.cache_invalidation_table_name.value
  resource_role_mappings_table_arn        = data.aws_ssm_parameter.resource_role_mappings_table_arn.value
  resource_role_mappings_table_name       = data.aws_ssm_parameter.resource_role_mappings_table_name.value
  resource_role_mappings_table_stream_arn = data.aws_ssm_parameter.resource_role_mappings_table_stream_arn.value
  roles_table_arn                         = data.aws_ssm_parameter.roles_table_arn.value
  roles_table_name                        = data.aws_ssm_parameter.roles_table_name.value
  roles_table_stream_arn                  = data.aws_ssm_parameter.roles_table_stream_arn.value

  # Namespace handoff
  namespaces_table_arn = data.aws_ssm_parameter.namespaces_table_arn.value

  # Fn ARNs for path_handlers
  namespace_api_fn_arn      = data.aws_ssm_parameter.namespace_api_fn_arn.value
  namespace_roles_fn_arn    = data.aws_ssm_parameter.namespace_roles_api_fn_arn.value
  namespace_platform_fn_arn = data.aws_ssm_parameter.namespace_platform_roles_api_fn_arn.value
  namespace_grants_fn_arn   = data.aws_ssm_parameter.namespace_grants_api_fn_arn.value
  sources_fn_arn            = data.aws_ssm_parameter.sources_api_fn_arn.value
  metric_fn_arn             = data.aws_ssm_parameter.metric_api_fn_arn.value
  ontology_fn_arn           = data.aws_ssm_parameter.ontology_api_fn_arn.value
  data_layer_fn_arn         = data.aws_ssm_parameter.data_layer_api_fn_arn.value

  # 50-agentcore now runs before 60-api-edge (see LAYERS in Makefile), so
  # the runtime ARN is always available from SSM by the time we apply.
  serve_runtime_arn = data.aws_ssm_parameter.serve_runtime_arn.value
}

data "aws_ssm_parameter" "vpc_id" { name = "${local.ssm_prefix}/network/vpc-id" }
data "aws_ssm_parameter" "private_subnet_ids" { name = "${local.ssm_prefix}/network/private-subnet-ids" }
data "aws_ssm_parameter" "lambda_security_group_id" { name = "${local.ssm_prefix}/network/lambda-security-group-id" }

data "aws_ssm_parameter" "cache_invalidation_table_arn" { name = "${local.ssm_prefix}/authnz/cache-invalidation-table-arn" }
data "aws_ssm_parameter" "cache_invalidation_table_name" { name = "${local.ssm_prefix}/authnz/cache-invalidation-table-name" }
data "aws_ssm_parameter" "resource_role_mappings_table_arn" { name = "${local.ssm_prefix}/authnz/resource-role-mappings-table-arn" }
data "aws_ssm_parameter" "resource_role_mappings_table_name" { name = "${local.ssm_prefix}/authnz/resource-role-mappings-table-name" }
data "aws_ssm_parameter" "resource_role_mappings_table_stream_arn" { name = "${local.ssm_prefix}/authnz/resource-role-mappings-table-stream-arn" }
data "aws_ssm_parameter" "roles_table_arn" { name = "${local.ssm_prefix}/authnz/roles-table-arn" }
data "aws_ssm_parameter" "roles_table_name" { name = "${local.ssm_prefix}/authnz/roles-table-name" }
data "aws_ssm_parameter" "roles_table_stream_arn" { name = "${local.ssm_prefix}/authnz/roles-table-stream-arn" }

data "aws_ssm_parameter" "namespaces_table_arn" { name = "${local.ssm_prefix}/namespace/namespaces-table-arn" }
data "aws_ssm_parameter" "namespace_api_fn_arn" { name = "${local.ssm_prefix}/namespace/api-fn-arn" }
data "aws_ssm_parameter" "namespace_roles_api_fn_arn" { name = "${local.ssm_prefix}/namespace/roles-api-fn-arn" }
data "aws_ssm_parameter" "namespace_platform_roles_api_fn_arn" { name = "${local.ssm_prefix}/namespace/platform-roles-api-fn-arn" }
data "aws_ssm_parameter" "namespace_grants_api_fn_arn" { name = "${local.ssm_prefix}/namespace/grants-api-fn-arn" }
data "aws_ssm_parameter" "sources_api_fn_arn" { name = "${local.ssm_prefix}/sources/api-fn-arn" }
data "aws_ssm_parameter" "metric_api_fn_arn" { name = "${local.ssm_prefix}/metric/api-fn-arn" }
data "aws_ssm_parameter" "ontology_api_fn_arn" { name = "${local.ssm_prefix}/ontology-engine/api-fn-arn" }
data "aws_ssm_parameter" "data_layer_api_fn_arn" { name = "${local.ssm_prefix}/data-layer/api-fn-arn" }

data "aws_ssm_parameter" "serve_runtime_arn" { name = "${local.ssm_prefix}/serve/runtime-arn" }

# Cognito identifiers (Cognito mode only; empty string when idp_type=OIDC).
data "aws_ssm_parameter" "user_pool_id" {
  count = var.idp_type != "OIDC" ? 1 : 0
  name  = "${local.ssm_prefix}/userpool-id"
}
data "aws_ssm_parameter" "userpool_client_id" {
  count = var.idp_type != "OIDC" ? 1 : 0
  name  = "${local.ssm_prefix}/userpool-client-id"
}
data "aws_ssm_parameter" "userpool_domain" {
  count = var.idp_type != "OIDC" ? 1 : 0
  name  = "${local.ssm_prefix}/userpool-domain"
}
