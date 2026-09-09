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

  # Custom domain / CORS: same rule as the root — all-or-nothing set.
  custom_domain_fields = {
    ui_domain_name      = var.ui_domain_name
    ui_certificate_arn  = var.ui_certificate_arn
    api_domain_name     = var.api_domain_name
    api_certificate_arn = var.api_certificate_arn
    hosted_zone_id      = var.hosted_zone_id
  }
  custom_domain_enabled = length([for v in values(local.custom_domain_fields) : v if v != null]) == length(local.custom_domain_fields)
  allowed_origin        = local.custom_domain_enabled ? "https://${var.ui_domain_name}" : "*"

  # Upstream SSM reads
  vpc_id                            = data.aws_ssm_parameter.vpc_id.value
  cloud_map_namespace_id            = data.aws_ssm_parameter.service_namespace_id.value
  lambda_security_group_id          = data.aws_ssm_parameter.lambda_security_group_id.value
  private_subnet_ids                = nonsensitive(split(",", data.aws_ssm_parameter.private_subnet_ids.value))
  cache_invalidation_table_name     = data.aws_ssm_parameter.cache_invalidation_table_name.value
  ontology_bucket_name              = data.aws_ssm_parameter.ontology_bucket_name.value
  opensearch_collection_name        = data.aws_ssm_parameter.opensearch_collection_name.value
  opensearch_endpoint               = data.aws_ssm_parameter.opensearch_endpoint.value
  resource_role_mappings_table_arn  = data.aws_ssm_parameter.resource_role_mappings_table_arn.value
  resource_role_mappings_table_name = data.aws_ssm_parameter.resource_role_mappings_table_name.value
  roles_table_arn                   = data.aws_ssm_parameter.roles_table_arn.value
  roles_table_name                  = data.aws_ssm_parameter.roles_table_name.value
}

data "aws_ssm_parameter" "vpc_id" { name = "${local.ssm_prefix}/network/vpc-id" }
data "aws_ssm_parameter" "service_namespace_id" { name = "${local.ssm_prefix}/network/service-namespace-id" }
data "aws_ssm_parameter" "lambda_security_group_id" { name = "${local.ssm_prefix}/network/lambda-security-group-id" }
data "aws_ssm_parameter" "private_subnet_ids" { name = "${local.ssm_prefix}/network/private-subnet-ids" }
data "aws_ssm_parameter" "cache_invalidation_table_name" { name = "${local.ssm_prefix}/authnz/cache-invalidation-table-name" }
data "aws_ssm_parameter" "ontology_bucket_name" { name = "${local.ssm_prefix}/storage/ontology-bucket-name" }
data "aws_ssm_parameter" "opensearch_collection_name" { name = "${local.ssm_prefix}/opensearch/collection-name" }
data "aws_ssm_parameter" "opensearch_endpoint" { name = "${local.ssm_prefix}/opensearch/endpoint" }
data "aws_ssm_parameter" "resource_role_mappings_table_arn" { name = "${local.ssm_prefix}/authnz/resource-role-mappings-table-arn" }
data "aws_ssm_parameter" "resource_role_mappings_table_name" { name = "${local.ssm_prefix}/authnz/resource-role-mappings-table-name" }
data "aws_ssm_parameter" "roles_table_arn" { name = "${local.ssm_prefix}/authnz/roles-table-arn" }
data "aws_ssm_parameter" "roles_table_name" { name = "${local.ssm_prefix}/authnz/roles-table-name" }
