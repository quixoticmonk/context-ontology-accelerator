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

  event_source_prefix = coalesce(
    var.event_source_prefix != "" ? var.event_source_prefix : null,
    var.resource_prefix,
  )

  brand_env = {
    GRAPH_BASE_URI      = var.graph_base_uri
    EVENT_SOURCE_PREFIX = local.event_source_prefix
  }

  group_claim_name = var.idp_type == "OIDC" && var.oidc_settings != null ? coalesce(var.oidc_settings.group_claim, "groups") : "cognito:groups"

  # Network handoff
  vpc_id   = data.aws_ssm_parameter.vpc_id.value
  vpc_cidr = data.aws_ssm_parameter.vpc_cidr.value
  # aws_ssm_parameter marks .value sensitive. Subnet IDs are not secret,
  # and downstream modules use them in for_each which rejects sensitive
  # values. Explicitly unmark.
  private_subnet_ids       = nonsensitive(split(",", data.aws_ssm_parameter.private_subnet_ids.value))
  lambda_security_group_id = data.aws_ssm_parameter.lambda_security_group_id.value
  aoss_security_group_id   = data.aws_ssm_parameter.aoss_security_group_id.value
  aoss_vpc_endpoint_id_raw = data.aws_ssm_parameter.aoss_vpc_endpoint_id.value
  aoss_vpc_endpoint_id     = local.aoss_vpc_endpoint_id_raw == "none" ? null : local.aoss_vpc_endpoint_id_raw

  # Storage handoff
  athena_results_bucket_name = data.aws_ssm_parameter.athena_results_bucket_name.value
  athena_spill_bucket_name   = data.aws_ssm_parameter.athena_spill_bucket_name.value
  ontology_bucket_arn        = data.aws_ssm_parameter.ontology_bucket_arn.value
  opensearch_collection_arn  = data.aws_ssm_parameter.opensearch_collection_arn.value
  opensearch_collection_name = data.aws_ssm_parameter.opensearch_collection_name.value
  opensearch_endpoint        = data.aws_ssm_parameter.opensearch_endpoint.value
  neptune_endpoint           = data.aws_ssm_parameter.neptune_endpoint.value
  neptune_cluster_arn        = data.aws_ssm_parameter.neptune_cluster_arn.value

  # AuthNZ handoff
  resource_role_mappings_table_arn  = data.aws_ssm_parameter.resource_role_mappings_table_arn.value
  resource_role_mappings_table_name = data.aws_ssm_parameter.resource_role_mappings_table_name.value
  roles_table_arn                   = data.aws_ssm_parameter.roles_table_arn.value
  roles_table_name                  = data.aws_ssm_parameter.roles_table_name.value

  # Namespace + sources handoff
  namespaces_table_arn  = data.aws_ssm_parameter.namespaces_table_arn.value
  namespaces_table_name = data.aws_ssm_parameter.namespaces_table_name.value
  sources_table_name    = data.aws_ssm_parameter.sources_table_name.value

  # Auth-idp handoff
  issuer_url         = data.aws_ssm_parameter.issuer.value
  mcp_client_id      = data.aws_ssm_parameter.mcp_client_id.value
  userpool_client_id = data.aws_ssm_parameter.userpool_client_id.value

  # Service ARNs consumed by MCP
  metric_service_lambda_arn = data.aws_ssm_parameter.metric_api_fn_arn.value
  ontology_proxy_lambda_arn = data.aws_ssm_parameter.ontology_api_fn_arn.value

  # AgentCore-supported AZ names resolved by stack 00-network.
  agentcore_az_names = split(",", nonsensitive(data.aws_ssm_parameter.agentcore_supported_az_names.value))

  # ECR handoff (from stack 25-ecr)
  context_manager_ecr_repository_url = data.aws_ssm_parameter.context_manager_ecr_url.value
  context_manager_ecr_repository_arn = data.aws_ssm_parameter.context_manager_ecr_arn.value
  mcp_server_ecr_repository_url      = data.aws_ssm_parameter.mcp_server_ecr_url.value
  mcp_server_ecr_repository_arn      = data.aws_ssm_parameter.mcp_server_ecr_arn.value
}

data "aws_ssm_parameter" "vpc_id" { name = "${local.ssm_prefix}/network/vpc-id" }
data "aws_ssm_parameter" "vpc_cidr" { name = "${local.ssm_prefix}/network/vpc-cidr-block" }
data "aws_ssm_parameter" "private_subnet_ids" { name = "${local.ssm_prefix}/network/private-subnet-ids" }
data "aws_ssm_parameter" "lambda_security_group_id" { name = "${local.ssm_prefix}/network/lambda-security-group-id" }
data "aws_ssm_parameter" "aoss_security_group_id" { name = "${local.ssm_prefix}/network/aoss-security-group-id" }
data "aws_ssm_parameter" "aoss_vpc_endpoint_id" { name = "${local.ssm_prefix}/network/aoss-vpc-endpoint-id" }

data "aws_ssm_parameter" "athena_results_bucket_name" { name = "${local.ssm_prefix}/storage/athena-results-bucket-name" }
data "aws_ssm_parameter" "athena_spill_bucket_name" { name = "${local.ssm_prefix}/storage/athena-spill-bucket-name" }
data "aws_ssm_parameter" "ontology_bucket_arn" { name = "${local.ssm_prefix}/storage/ontology-bucket-arn" }
data "aws_ssm_parameter" "opensearch_collection_arn" { name = "${local.ssm_prefix}/storage/opensearch-collection-arn" }
data "aws_ssm_parameter" "opensearch_collection_name" { name = "${local.ssm_prefix}/opensearch/collection-name" }
data "aws_ssm_parameter" "opensearch_endpoint" { name = "${local.ssm_prefix}/opensearch/endpoint" }
data "aws_ssm_parameter" "neptune_endpoint" { name = "${local.ssm_prefix}/storage/neptune-endpoint" }
data "aws_ssm_parameter" "neptune_cluster_arn" { name = "${local.ssm_prefix}/storage/neptune-cluster-arn-full" }

data "aws_ssm_parameter" "resource_role_mappings_table_arn" { name = "${local.ssm_prefix}/authnz/resource-role-mappings-table-arn" }
data "aws_ssm_parameter" "resource_role_mappings_table_name" { name = "${local.ssm_prefix}/authnz/resource-role-mappings-table-name" }
data "aws_ssm_parameter" "roles_table_arn" { name = "${local.ssm_prefix}/authnz/roles-table-arn" }
data "aws_ssm_parameter" "roles_table_name" { name = "${local.ssm_prefix}/authnz/roles-table-name" }

data "aws_ssm_parameter" "namespaces_table_arn" { name = "${local.ssm_prefix}/namespace/namespaces-table-arn" }
data "aws_ssm_parameter" "namespaces_table_name" { name = "${local.ssm_prefix}/namespace/namespaces-table-name" }
data "aws_ssm_parameter" "sources_table_name" { name = "${local.ssm_prefix}/sources/sources-table-name" }

data "aws_ssm_parameter" "issuer" { name = "${local.ssm_prefix}/issuer" }
data "aws_ssm_parameter" "mcp_client_id" { name = "${local.ssm_prefix}/mcp-client-id" }
data "aws_ssm_parameter" "userpool_client_id" { name = "${local.ssm_prefix}/userpool-client-id" }

data "aws_ssm_parameter" "metric_api_fn_arn" { name = "${local.ssm_prefix}/metric/api-fn-arn" }
data "aws_ssm_parameter" "ontology_api_fn_arn" { name = "${local.ssm_prefix}/ontology-engine/api-fn-arn" }

data "aws_ssm_parameter" "agentcore_supported_az_names" { name = "${local.ssm_prefix}/network/agentcore-supported-az-names" }

data "aws_ssm_parameter" "context_manager_ecr_url" { name = "${local.ssm_prefix}/ecr/context-manager/url" }
data "aws_ssm_parameter" "context_manager_ecr_arn" { name = "${local.ssm_prefix}/ecr/context-manager/arn" }
data "aws_ssm_parameter" "mcp_server_ecr_url" { name = "${local.ssm_prefix}/ecr/mcp-server/url" }
data "aws_ssm_parameter" "mcp_server_ecr_arn" { name = "${local.ssm_prefix}/ecr/mcp-server/arn" }
