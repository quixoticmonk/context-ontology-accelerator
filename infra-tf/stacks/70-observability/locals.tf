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

  # Lambda function ARNs → extract function names for the alarm module.
  # split(":", arn)[6] pulls the function-name segment from a Lambda ARN.
  lambda_arns = [
    data.aws_ssm_parameter.sources_api_fn_arn.value,
    data.aws_ssm_parameter.sources_db_connector_fn_arn.value,
    data.aws_ssm_parameter.sources_bulk_review_worker_fn_arn.value,
    data.aws_ssm_parameter.sources_preprocessing_fn_arn.value,
    data.aws_ssm_parameter.sources_db_scan_trigger_fn_arn.value,
    data.aws_ssm_parameter.sources_doc_cleanup_fn_arn.value,
    data.aws_ssm_parameter.sources_doc_trigger_fn_arn.value,
    data.aws_ssm_parameter.sources_federation_provisioner_fn_arn.value,
    data.aws_ssm_parameter.metric_api_fn_arn.value,
    data.aws_ssm_parameter.metric_import_worker_fn_arn.value,
    data.aws_ssm_parameter.metric_import_dlq_recovery_fn_arn.value,
    data.aws_ssm_parameter.aoss_proxy_fn_arn.value,
  ]

  lambda_names = toset([for a in local.lambda_arns : element(split(":", a), 6)])
}

data "aws_ssm_parameter" "sources_api_fn_arn" { name = "${local.ssm_prefix}/sources/api-fn-arn" }
data "aws_ssm_parameter" "sources_db_connector_fn_arn" { name = "${local.ssm_prefix}/sources/db-connector-fn-arn" }
data "aws_ssm_parameter" "sources_bulk_review_worker_fn_arn" { name = "${local.ssm_prefix}/sources/bulk-review-worker-fn-arn" }
data "aws_ssm_parameter" "sources_preprocessing_fn_arn" { name = "${local.ssm_prefix}/sources/preprocessing-fn-arn" }
data "aws_ssm_parameter" "sources_db_scan_trigger_fn_arn" { name = "${local.ssm_prefix}/sources/db-scan-trigger-fn-arn" }
data "aws_ssm_parameter" "sources_doc_cleanup_fn_arn" { name = "${local.ssm_prefix}/sources/doc-cleanup-fn-arn" }
data "aws_ssm_parameter" "sources_doc_trigger_fn_arn" { name = "${local.ssm_prefix}/sources/doc-trigger-fn-arn" }
data "aws_ssm_parameter" "sources_federation_provisioner_fn_arn" { name = "${local.ssm_prefix}/sources/federation-provisioner-fn-arn" }
data "aws_ssm_parameter" "metric_api_fn_arn" { name = "${local.ssm_prefix}/metric/api-fn-arn" }
data "aws_ssm_parameter" "metric_import_worker_fn_arn" { name = "${local.ssm_prefix}/metric/import-worker-fn-arn" }
data "aws_ssm_parameter" "metric_import_dlq_recovery_fn_arn" { name = "${local.ssm_prefix}/metric/import-dlq-recovery-fn-arn" }
data "aws_ssm_parameter" "aoss_proxy_fn_arn" { name = "${local.ssm_prefix}/serve/aoss-proxy-fn-arn" }

data "aws_ssm_parameter" "sources_db_scan_state_machine_arn" { name = "${local.ssm_prefix}/sources/db-scan-state-machine-arn" }
data "aws_ssm_parameter" "sources_doc_ingestion_state_machine_arn" { name = "${local.ssm_prefix}/sources/doc-ingestion-state-machine-arn" }
data "aws_ssm_parameter" "sources_doc_deletion_state_machine_arn" { name = "${local.ssm_prefix}/sources/doc-deletion-state-machine-arn" }

data "aws_ssm_parameter" "sources_db_scan_dlq_arn" { name = "${local.ssm_prefix}/sources/db-scan-dlq-arn" }
data "aws_ssm_parameter" "sources_bulk_review_dlq_arn" { name = "${local.ssm_prefix}/sources/bulk-review-dlq-arn" }
data "aws_ssm_parameter" "sources_doc_ingestion_dlq_arn" { name = "${local.ssm_prefix}/sources/doc-ingestion-dlq-arn" }
data "aws_ssm_parameter" "metric_import_dlq_arn" { name = "${local.ssm_prefix}/metric/import-dlq-arn" }

data "aws_ssm_parameter" "metric_import_jobs_table_name" { name = "${local.ssm_prefix}/metric/import-jobs-table-name" }
data "aws_ssm_parameter" "ontology_dynamodb_table" { name = "${local.ssm_prefix}/ontology-engine/dynamodb-table" }

data "aws_ssm_parameter" "ontology_cluster_name" { name = "${local.ssm_prefix}/ontology-engine/cluster-name" }
data "aws_ssm_parameter" "ontology_service_name" { name = "${local.ssm_prefix}/ontology-engine/service-name" }
data "aws_ssm_parameter" "vkg_cluster_name" { name = "${local.ssm_prefix}/vkg/cluster-name-full" }
