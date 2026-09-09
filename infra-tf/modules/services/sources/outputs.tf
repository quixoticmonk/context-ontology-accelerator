# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Outputs seeded by sub-turn 1 (DDB + S3 + SQS + ECS). Additional
# outputs (Lambda ARNs, SFN ARNs, ECR repos) added by sub-turns 2-4.

output "bulk_review_dlq_arn" {
  description = "ARN of the bulk-review DLQ."
  value       = aws_sqs_queue.bulk_review_dlq.arn
}

output "bulk_review_queue_arn" {
  description = "ARN of the bulk-review queue."
  value       = aws_sqs_queue.bulk_review.arn
}

output "bulk_review_queue_url" {
  description = "URL of the bulk-review queue."
  value       = aws_sqs_queue.bulk_review.url
}

output "db_connector_dlq_arn" {
  description = "ARN of the discovery Lambda's Lambda-native DLQ."
  value       = aws_sqs_queue.db_connector_dlq.arn
}

output "db_enrichment_cluster_arn" {
  description = "ECS cluster ARN hosting the database enrichment task."
  value       = aws_ecs_cluster.db_enrichment.arn
}

output "db_scan_dlq_arn" {
  description = "ARN of the db-scan DLQ."
  value       = aws_sqs_queue.db_scan_dlq.arn
}

output "db_scan_queue_arn" {
  description = "ARN of the db-scan queue (feeds the SFN via the trigger Lambda)."
  value       = aws_sqs_queue.db_scan.arn
}

output "db_scan_queue_url" {
  description = "URL of the db-scan queue."
  value       = aws_sqs_queue.db_scan.url
}

output "doc_ingestion_dlq_arn" {
  description = "ARN of the doc-ingestion DLQ."
  value       = aws_sqs_queue.doc_ingestion_dlq.arn
}

output "doc_ingestion_queue_arn" {
  description = "ARN of the doc-ingestion queue (feeds the SFN via the trigger Lambda)."
  value       = aws_sqs_queue.doc_ingestion.arn
}

output "doc_ingestion_queue_url" {
  description = "URL of the doc-ingestion queue."
  value       = aws_sqs_queue.doc_ingestion.url
}

output "kg_build_cluster_arn" {
  description = "ECS cluster ARN hosting the doc-kg-build task (with Container Insights v2)."
  value       = aws_ecs_cluster.kg_build.arn
}

output "sources_access_logs_bucket_arn" {
  description = "Access logs bucket ARN (shared logging target for the sources-data bucket)."
  value       = aws_s3_bucket.access_logs.arn
}

output "sources_bucket_arn" {
  description = "sources-data S3 bucket ARN."
  value       = aws_s3_bucket.sources_data.arn
}

output "sources_bucket_name" {
  description = "sources-data S3 bucket name."
  value       = aws_s3_bucket.sources_data.bucket
}

output "sources_table_arn" {
  description = "sources DDB table ARN."
  value       = aws_dynamodb_table.sources.arn
}

output "sources_table_name" {
  description = "sources DDB table name."
  value       = aws_dynamodb_table.sources.name
}

output "source_scan_jobs_table_arn" {
  description = "source-scan-jobs DDB table ARN."
  value       = aws_dynamodb_table.source_scan_jobs.arn
}

output "source_scan_jobs_table_name" {
  description = "source-scan-jobs DDB table name."
  value       = aws_dynamodb_table.source_scan_jobs.name
}

# ═════════════════════════════════════════════════════════════════════
#  Sub-turn 2 outputs (database pipeline)
# ═════════════════════════════════════════════════════════════════════

output "db_connector_fn_arn" {
  description = "Discovery Lambda ARN."
  value       = aws_lambda_function.db_connector.arn
}

output "db_enrichment_task_definition_family" {
  description = "Family of the database enrichment Fargate task definition."
  value       = aws_ecs_task_definition.db_enrichment.family
}

output "db_scan_state_machine_arn" {
  description = "dbScan Step Functions state machine ARN."
  value       = aws_sfn_state_machine.db_scan.arn
}

output "db_scan_reaper_fn_arn" {
  description = "Terminal-status safety-net reaper Lambda ARN."
  value       = aws_lambda_function.db_scan_reaper.arn
}

output "db_scan_trigger_fn_arn" {
  description = "SQS→SFN trigger Lambda ARN."
  value       = aws_lambda_function.db_scan_trigger.arn
}

output "federation_provisioner_fn_arn" {
  description = "Federation provisioner Lambda ARN."
  value       = aws_lambda_function.federation_provisioner.arn
}

output "federation_provisioner_role_arn" {
  description = "Federation provisioner IAM role ARN. Sub-turn 4 registers this as a Lake Formation data-lake admin."
  value       = aws_iam_role.federation_provisioner.arn
}

output "bulk_review_worker_fn_arn" {
  description = "Bulk review worker Lambda ARN (async ApproveSource/RejectSource)."
  value       = aws_lambda_function.bulk_review_worker.arn
}

# ═════════════════════════════════════════════════════════════════════
#  Sub-turn 3 outputs (documents pipeline)
# ═════════════════════════════════════════════════════════════════════

output "batch_inference_role_arn" {
  description = "Bedrock batch inference service role ARN (passed to the kg-build task for batch model-invocation jobs)."
  value       = aws_iam_role.batch_inference.arn
}

output "doc_cleanup_fn_arn" {
  description = "Doc cleanup Lambda ARN (S3 + DDB cleanup on document source deletion)."
  value       = aws_lambda_function.doc_cleanup.arn
}

output "doc_deletion_state_machine_arn" {
  description = "Doc deletion Step Functions state machine ARN."
  value       = aws_sfn_state_machine.doc_deletion.arn
}

output "doc_ingestion_state_machine_arn" {
  description = "Doc ingestion Step Functions state machine ARN."
  value       = aws_sfn_state_machine.doc_ingestion.arn
}

output "doc_trigger_fn_arn" {
  description = "SQS → doc-ingestion SFN trigger Lambda ARN."
  value       = aws_lambda_function.doc_trigger.arn
}

output "kg_build_task_definition_family" {
  description = "Family of the doc-kg-build Fargate task definition."
  value       = aws_ecs_task_definition.kg_build.family
}

output "preprocessing_fn_arn" {
  description = "Doc preprocessing DockerImageFunction ARN."
  value       = aws_lambda_function.preprocessing.arn
}

# ═════════════════════════════════════════════════════════════════════
#  Sub-turn 4 outputs (Sources API + module surface)
# ═════════════════════════════════════════════════════════════════════

output "sources_api_fn_arn" {
  description = "Unified sources API Lambda ARN. Downstream API stack points to this for the /namespaces/*/sources/* routes."
  value       = aws_lambda_function.sources_api.arn
}

output "sources_api_fn_name" {
  description = "Unified sources API Lambda function name."
  value       = aws_lambda_function.sources_api.function_name
}

output "sources_api_role_arn" {
  description = "Sources API Lambda execution role ARN. The namespace deletion pipeline's DeleteSources Lambda invokes the sources API by function ARN, but callers that need to grant sources-api additional permissions bind against this role."
  value       = aws_iam_role.sources_api.arn
}
