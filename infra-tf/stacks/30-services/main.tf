# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Stack 30 — Static services (metric-service, vkg, ontology, data-layer).
# ECS/ECR-heavy stack. ECR repos are owned by stack 25-ecr, so this stack
# applies once with the ontology service running desired_count=1 out of
# the gate — no image-push flip required.

module "metric_service" {
  source = "../../modules/services/metric-service"

  allowed_origin               = local.allowed_origin
  aoss_security_group_id       = local.aoss_security_group_id
  bedrock_embed_model_id       = var.bedrock_embed_model_id
  brand_env                    = local.brand_env
  lambda_security_group_id     = local.lambda_security_group_id
  metric_service_zip_path      = "${path.root}/../../artifacts/lambdas/metric-service.zip"
  name_prefix                  = local.name_prefix
  namespaces_table_name        = local.namespaces_table_name
  neptune_cluster_arn          = local.neptune_cluster_arn
  neptune_endpoint             = local.neptune_endpoint
  opensearch_collection_arn    = local.opensearch_collection_arn
  opensearch_collection_name   = local.opensearch_collection_name
  opensearch_endpoint          = local.opensearch_endpoint
  private_subnet_ids           = local.private_subnet_ids
  region                       = var.region
  smus_domain_id               = local.smus_domain_id
  smus_project_access_role_arn = local.smus_project_access_role_arn
  sources_table_name           = local.sources_table_name_by_convention
  ssm_prefix                   = local.ssm_prefix
  vpc_id                       = local.vpc_id
}

module "vkg" {
  source = "../../modules/services/vkg"

  ecr_repository_url          = local.vkg_ecr_repository_url
  ecs_security_group_id       = local.ecs_security_group_id
  event_source_prefix         = local.event_source_prefix
  lambda_reserved_concurrency = var.lambda_reserved_concurrency
  lambda_security_group_id    = local.lambda_security_group_id
  logs_kms_key_arn            = local.logs_kms_key_arn
  name_prefix                 = local.name_prefix
  ontology_bucket_arn         = local.ontology_bucket_arn
  ontology_bucket_name        = local.ontology_bucket_name
  private_subnet_ids          = local.private_subnet_ids
  region                      = var.region
  service_namespace_id        = local.service_namespace_id
  service_namespace_name      = local.service_namespace_name
  ssm_prefix                  = local.ssm_prefix
  vkg_reload_zip_path         = "${path.root}/../../artifacts/lambdas/vkg-reload.zip"
  vpc_id                      = local.vpc_id
}

module "ontology" {
  source = "../../modules/services/ontology"

  allowed_origin                 = local.allowed_origin
  aoss_security_group_id         = local.aoss_security_group_id
  bedrock_chat_model_id          = var.bedrock_chat_model_id
  bedrock_embed_dimensions       = var.bedrock_embed_dimensions
  bedrock_embed_model_id         = var.bedrock_embed_model_id
  bedrock_induction_llm_model_id = var.bedrock_induction_llm_model_id
  ecr_repository_url             = local.ontology_ecr_repository_url
  ecs_security_group_id          = local.ecs_security_group_id
  lambda_security_group_id       = local.lambda_security_group_id
  logs_kms_key_arn               = local.logs_kms_key_arn
  name_prefix                    = local.name_prefix
  namespaces_table_name          = local.namespaces_table_name
  neptune_cluster_arn            = local.neptune_cluster_arn
  neptune_endpoint               = local.neptune_endpoint
  ontology_api_zip_path          = "${path.root}/../../artifacts/lambdas/ontology-api.zip"
  ontology_bucket_arn            = local.ontology_bucket_arn
  ontology_bucket_name           = local.ontology_bucket_name
  opensearch_collection_arn      = local.opensearch_collection_arn
  opensearch_collection_name     = local.opensearch_collection_name
  opensearch_endpoint            = local.opensearch_endpoint
  private_subnet_ids             = local.private_subnet_ids
  region                         = var.region
  service_namespace_id           = local.service_namespace_id
  service_namespace_name         = local.service_namespace_name
  smus_domain_id                 = local.smus_domain_id
  smus_project_access_role_arn   = local.smus_project_access_role_arn
  sources_table_name             = local.sources_table_name_by_convention
  ssm_prefix                     = local.ssm_prefix
  vpc_id                         = local.vpc_id
}

# data-layer moved to stack 55-data-layer — it needs the serve
# AgentCore Runtime ARN (from stack 50-agentcore) and stack 60-api-edge
# needs its Lambda ARN, so it can't live here without a two-phase apply
# loop.

# ── Stack-added SSM writes for observability consumers ───────────────

resource "aws_ssm_parameter" "metric_import_worker_fn_arn" {
  name  = "${local.ssm_prefix}/metric/import-worker-fn-arn"
  type  = "String"
  value = module.metric_service.import_worker_fn_arn
}

resource "aws_ssm_parameter" "metric_import_dlq_arn" {
  name  = "${local.ssm_prefix}/metric/import-dlq-arn"
  type  = "String"
  value = module.metric_service.import_dlq_arn
}

resource "aws_ssm_parameter" "ontology_cluster_name" {
  name  = "${local.ssm_prefix}/ontology-engine/cluster-name"
  type  = "String"
  value = module.ontology.cluster_name
}

resource "aws_ssm_parameter" "vkg_cluster_name" {
  name  = "${local.ssm_prefix}/vkg/cluster-name-full"
  type  = "String"
  value = module.vkg.cluster_name
}
