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

  # Network handoff
  vpc_id                      = data.aws_ssm_parameter.vpc_id.value
  private_subnet_ids          = nonsensitive(split(",", data.aws_ssm_parameter.private_subnet_ids.value))
  lambda_security_group_id    = data.aws_ssm_parameter.lambda_security_group_id.value
  ecs_security_group_id       = data.aws_ssm_parameter.ecs_security_group_id.value
  aoss_security_group_id      = data.aws_ssm_parameter.aoss_security_group_id.value
  connector_security_group_id = data.aws_ssm_parameter.connector_security_group_id.value

  # Storage handoff
  ontology_bucket_arn        = data.aws_ssm_parameter.ontology_bucket_arn.value
  opensearch_collection_name = data.aws_ssm_parameter.opensearch_collection_name.value
  opensearch_collection_arn  = data.aws_ssm_parameter.opensearch_collection_arn.value
  opensearch_endpoint        = data.aws_ssm_parameter.opensearch_endpoint.value
  neptune_endpoint           = data.aws_ssm_parameter.neptune_endpoint.value
  neptune_cluster_arn        = data.aws_ssm_parameter.neptune_cluster_arn.value
  athena_results_bucket_arn  = data.aws_ssm_parameter.athena_results_bucket_arn.value
  athena_spill_bucket_arn    = data.aws_ssm_parameter.athena_spill_bucket_arn.value
  athena_spill_bucket_name   = data.aws_ssm_parameter.athena_spill_bucket_name.value

  # Namespace handoff
  namespaces_table_arn         = data.aws_ssm_parameter.namespaces_table_arn.value
  namespaces_table_name        = data.aws_ssm_parameter.namespaces_table_name.value
  smus_domain_id               = data.aws_ssm_parameter.smus_domain_id.value
  smus_project_access_role_arn = data.aws_ssm_parameter.smus_project_access_role_arn.value

  # ECR handoff (from stack 25-ecr)
  db_enrichment_ecr_repository_url = data.aws_ssm_parameter.db_enrichment_ecr_url.value
  preprocessing_ecr_repository_url = data.aws_ssm_parameter.preprocessing_ecr_url.value
  kg_build_ecr_repository_url      = data.aws_ssm_parameter.kg_build_ecr_url.value

  # KMS handoff (from foundation stack)
  logs_kms_key_arn = data.aws_ssm_parameter.logs_kms_key_arn.value
}

data "aws_ssm_parameter" "vpc_id" { name = "${local.ssm_prefix}/network/vpc-id" }
data "aws_ssm_parameter" "private_subnet_ids" { name = "${local.ssm_prefix}/network/private-subnet-ids" }
data "aws_ssm_parameter" "lambda_security_group_id" { name = "${local.ssm_prefix}/network/lambda-security-group-id" }
data "aws_ssm_parameter" "ecs_security_group_id" { name = "${local.ssm_prefix}/network/ecs-security-group-id" }
data "aws_ssm_parameter" "aoss_security_group_id" { name = "${local.ssm_prefix}/network/aoss-security-group-id" }
data "aws_ssm_parameter" "connector_security_group_id" { name = "${local.ssm_prefix}/network/connector-security-group-id" }

data "aws_ssm_parameter" "ontology_bucket_arn" { name = "${local.ssm_prefix}/storage/ontology-bucket-arn" }
data "aws_ssm_parameter" "opensearch_collection_name" { name = "${local.ssm_prefix}/opensearch/collection-name" }
data "aws_ssm_parameter" "opensearch_collection_arn" { name = "${local.ssm_prefix}/opensearch/collection-arn" }
data "aws_ssm_parameter" "opensearch_endpoint" { name = "${local.ssm_prefix}/opensearch/endpoint" }
data "aws_ssm_parameter" "neptune_endpoint" { name = "${local.ssm_prefix}/storage/neptune-endpoint" }
data "aws_ssm_parameter" "neptune_cluster_arn" { name = "${local.ssm_prefix}/storage/neptune-cluster-arn-full" }
data "aws_ssm_parameter" "athena_results_bucket_arn" { name = "${local.ssm_prefix}/storage/athena-results-bucket-arn" }
data "aws_ssm_parameter" "athena_spill_bucket_arn" { name = "${local.ssm_prefix}/storage/athena-spill-bucket-arn" }
data "aws_ssm_parameter" "athena_spill_bucket_name" { name = "${local.ssm_prefix}/storage/athena-spill-bucket-name" }

data "aws_ssm_parameter" "namespaces_table_arn" { name = "${local.ssm_prefix}/namespace/namespaces-table-arn" }
data "aws_ssm_parameter" "namespaces_table_name" { name = "${local.ssm_prefix}/namespace/namespaces-table-name" }
data "aws_ssm_parameter" "smus_domain_id" { name = "${local.ssm_prefix}/smus/domain-id" }
data "aws_ssm_parameter" "smus_project_access_role_arn" { name = "${local.ssm_prefix}/smus/dz-project-access-role-arn" }

data "aws_ssm_parameter" "db_enrichment_ecr_url" { name = "${local.ssm_prefix}/ecr/sources-db-enrichment/url" }
data "aws_ssm_parameter" "preprocessing_ecr_url" { name = "${local.ssm_prefix}/ecr/sources-preprocessing/url" }
data "aws_ssm_parameter" "kg_build_ecr_url" { name = "${local.ssm_prefix}/ecr/sources-kg-build/url" }

data "aws_ssm_parameter" "logs_kms_key_arn" { name = "${local.ssm_prefix}/kms/logs-key-arn" }
