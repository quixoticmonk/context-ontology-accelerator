# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Stack 40 — Sources (ingestion, discovery, KG build). Largest module.

module "sources" {
  source = "../../modules/services/sources"

  allowed_origin                     = local.allowed_origin
  aoss_security_group_id             = local.aoss_security_group_id
  athena_results_bucket_arn          = local.athena_results_bucket_arn
  athena_spill_bucket_arn            = local.athena_spill_bucket_arn
  athena_spill_bucket_name           = local.athena_spill_bucket_name
  bedrock_chat_model_id              = var.bedrock_chat_model_id
  bedrock_embed_dimensions           = var.bedrock_embed_dimensions
  bedrock_embed_model_id             = var.bedrock_embed_model_id
  connector_security_group_id        = local.connector_security_group_id
  db_enrichment_ecr_repository_url   = local.db_enrichment_ecr_repository_url
  db_enrichment_image_tag_file       = "${path.root}/../../artifacts/images/sources-db-enrichment.tag"
  db_scan_enrichment_timeout_minutes = 120
  ecs_security_group_id              = local.ecs_security_group_id
  kg_build_ecr_repository_url        = local.kg_build_ecr_repository_url
  kg_build_image_tag_file            = "${path.root}/../../artifacts/images/sources-kg-build.tag"
  lakeformation_admin_zip_path       = "${path.root}/../../artifacts/lambdas/lakeformation-admin.zip"
  env                                = var.env
  lambda_reserved_concurrency        = var.lambda_reserved_concurrency
  lambda_security_group_id           = local.lambda_security_group_id
  name_prefix                        = local.name_prefix
  namespace_tag_key                  = "${var.resource_prefix}:namespace"
  namespaces_table_arn               = local.namespaces_table_arn
  namespaces_table_name              = local.namespaces_table_name
  neptune_cluster_arn                = local.neptune_cluster_arn
  neptune_endpoint                   = local.neptune_endpoint
  ontology_bucket_arn                = local.ontology_bucket_arn
  opensearch_collection_arn          = local.opensearch_collection_arn
  opensearch_collection_name         = local.opensearch_collection_name
  opensearch_endpoint                = local.opensearch_endpoint
  preprocessing_ecr_repository_url   = local.preprocessing_ecr_repository_url
  preprocessing_image_tag_file       = "${path.root}/../../artifacts/images/sources-preprocessing.tag"
  private_subnet_ids                 = local.private_subnet_ids
  region                             = var.region
  resource_prefix                    = var.resource_prefix
  smus_domain_id                     = local.smus_domain_id
  smus_project_access_role_arn       = local.smus_project_access_role_arn
  sources_db_trigger_zip_path        = "${path.root}/../../artifacts/lambdas/sources-db-trigger.zip"
  sources_doc_cleanup_zip_path       = "${path.root}/../../artifacts/lambdas/sources-doc-cleanup.zip"
  sources_doc_trigger_zip_path       = "${path.root}/../../artifacts/lambdas/sources-doc-trigger.zip"
  sources_zip_path                   = "${path.root}/../../artifacts/lambdas/sources.zip"
  ssm_prefix                         = local.ssm_prefix
  vpc_id                             = local.vpc_id
}

# ── Stack-added SSM writes for observability/agentcore consumers ─────

resource "aws_ssm_parameter" "sources_api_role_arn" {
  name  = "${local.ssm_prefix}/sources/api-role-arn"
  type  = "String"
  value = module.sources.sources_api_role_arn
}

resource "aws_ssm_parameter" "db_connector_fn_arn" {
  name  = "${local.ssm_prefix}/sources/db-connector-fn-arn"
  type  = "String"
  value = module.sources.db_connector_fn_arn
}

resource "aws_ssm_parameter" "bulk_review_worker_fn_arn" {
  name  = "${local.ssm_prefix}/sources/bulk-review-worker-fn-arn"
  type  = "String"
  value = module.sources.bulk_review_worker_fn_arn
}

resource "aws_ssm_parameter" "preprocessing_fn_arn" {
  name  = "${local.ssm_prefix}/sources/preprocessing-fn-arn"
  type  = "String"
  value = module.sources.preprocessing_fn_arn
}

resource "aws_ssm_parameter" "db_scan_trigger_fn_arn" {
  name  = "${local.ssm_prefix}/sources/db-scan-trigger-fn-arn"
  type  = "String"
  value = module.sources.db_scan_trigger_fn_arn
}

resource "aws_ssm_parameter" "doc_cleanup_fn_arn" {
  name  = "${local.ssm_prefix}/sources/doc-cleanup-fn-arn"
  type  = "String"
  value = module.sources.doc_cleanup_fn_arn
}

resource "aws_ssm_parameter" "doc_trigger_fn_arn" {
  name  = "${local.ssm_prefix}/sources/doc-trigger-fn-arn"
  type  = "String"
  value = module.sources.doc_trigger_fn_arn
}

resource "aws_ssm_parameter" "federation_provisioner_fn_arn" {
  name  = "${local.ssm_prefix}/sources/federation-provisioner-fn-arn"
  type  = "String"
  value = module.sources.federation_provisioner_fn_arn
}

resource "aws_ssm_parameter" "db_scan_dlq_arn" {
  name  = "${local.ssm_prefix}/sources/db-scan-dlq-arn"
  type  = "String"
  value = module.sources.db_scan_dlq_arn
}

resource "aws_ssm_parameter" "bulk_review_dlq_arn" {
  name  = "${local.ssm_prefix}/sources/bulk-review-dlq-arn"
  type  = "String"
  value = module.sources.bulk_review_dlq_arn
}

resource "aws_ssm_parameter" "doc_ingestion_dlq_arn" {
  name  = "${local.ssm_prefix}/sources/doc-ingestion-dlq-arn"
  type  = "String"
  value = module.sources.doc_ingestion_dlq_arn
}

resource "aws_ssm_parameter" "doc_deletion_state_machine_arn" {
  name  = "${local.ssm_prefix}/sources/doc-deletion-state-machine-arn"
  type  = "String"
  value = module.sources.doc_deletion_state_machine_arn
}
