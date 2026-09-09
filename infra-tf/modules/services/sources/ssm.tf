# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# SSM parameters mirroring the CDK sources stack writes. Runtime
# consumers (namespace deletion pipeline, ontology-engine catalog
# reader) read these to discover per-service resource identifiers.

resource "aws_ssm_parameter" "sources_api_fn_arn" {
  name        = "${var.ssm_prefix}/sources/api-fn-arn"
  type        = "String"
  value       = aws_lambda_function.sources_api.arn
  description = "Sources API Lambda ARN"
  tags        = local.tags
}

resource "aws_ssm_parameter" "sources_table_name" {
  name        = "${var.ssm_prefix}/sources/sources-table-name"
  type        = "String"
  value       = aws_dynamodb_table.sources.name
  description = "Sources DynamoDB table name"
  tags        = local.tags
}

resource "aws_ssm_parameter" "source_scan_jobs_table_name" {
  name        = "${var.ssm_prefix}/sources/source-scan-jobs-table-name"
  type        = "String"
  value       = aws_dynamodb_table.source_scan_jobs.name
  description = "Source scan jobs DynamoDB table name"
  tags        = local.tags
}

resource "aws_ssm_parameter" "doc_ingestion_queue_url" {
  name        = "${var.ssm_prefix}/sources/doc-ingestion-queue-url"
  type        = "String"
  value       = aws_sqs_queue.doc_ingestion.url
  description = "Sources document ingestion SQS queue URL"
  tags        = local.tags
}

resource "aws_ssm_parameter" "db_scan_queue_url" {
  name        = "${var.ssm_prefix}/sources/db-scan-queue-url"
  type        = "String"
  value       = aws_sqs_queue.db_scan.url
  description = "Sources database scan SQS queue URL"
  tags        = local.tags
}

resource "aws_ssm_parameter" "db_scan_state_machine_arn" {
  name        = "${var.ssm_prefix}/sources/db-scan-state-machine-arn"
  type        = "String"
  value       = aws_sfn_state_machine.db_scan.arn
  description = "Sources database scan Step Functions state machine ARN"
  tags        = local.tags
}

resource "aws_ssm_parameter" "doc_ingestion_state_machine_arn" {
  name        = "${var.ssm_prefix}/sources/doc-ingestion-state-machine-arn"
  type        = "String"
  value       = aws_sfn_state_machine.doc_ingestion.arn
  description = "Sources document ingestion Step Functions state machine ARN"
  tags        = local.tags
}

resource "aws_ssm_parameter" "db_connector_role_arn" {
  name        = "${var.ssm_prefix}/sources/db-connector-role-arn"
  type        = "String"
  value       = aws_iam_role.db_connector.arn
  description = "Sources database connector Lambda execution role ARN"
  tags        = local.tags
}

resource "aws_ssm_parameter" "db_enrichment_role_arn" {
  name        = "${var.ssm_prefix}/sources/db-enrichment-role-arn"
  type        = "String"
  value       = aws_iam_role.db_enrichment_task.arn
  description = "Sources database enrichment ECS task role ARN"
  tags        = local.tags
}
