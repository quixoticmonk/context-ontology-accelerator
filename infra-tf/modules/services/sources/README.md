# modules/services/sources

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.13 |
| aws | ~> 6.0 |
| null | ~> 3.2 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 6.0 |
| terraform | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_rule.databricks_parameter_batch_delete](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.databricks_parameter_write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.db_scan_reaper](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.databricks_parameter_batch_delete](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.databricks_parameter_write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.db_scan_reaper](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.databricks_parameter_audit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.db_enrichment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.kg_build](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_metric_filter.databricks_unexpected_write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_metric_filter) | resource |
| [aws_cloudwatch_metric_alarm.databricks_unexpected_write](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_dynamodb_table.source_scan_jobs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table.sources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_ecs_cluster.db_enrichment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_cluster.kg_build](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_task_definition.db_enrichment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_ecs_task_definition.kg_build](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_policy.batch_inference](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.bulk_review_worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.db_connector](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.db_enrichment_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.db_scan_reaper](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.db_scan_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.doc_cleanup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.doc_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.federated_catalog](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.federation_provisioner](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.glue_event_rescan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.idempotency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.kg_build_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.lakeformation_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.preprocessing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.rescan_scheduler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.sfn_db_scan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.sfn_doc_deletion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.sfn_doc_ingestion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.source_delete_worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.sources_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.batch_inference](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.bulk_review_worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.db_connector](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.db_enrichment_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.db_enrichment_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.db_scan_reaper](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.db_scan_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.doc_cleanup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.doc_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.federated_catalog](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.federation_provisioner](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.glue_event_rescan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.kg_build_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.kg_build_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.lakeformation_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.preprocessing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.rescan_scheduler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.sfn_db_scan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.sfn_doc_deletion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.sfn_doc_ingestion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.source_delete_worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.sources_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.batch_inference](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.bulk_review_worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.bulk_review_worker_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.db_connector](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.db_connector_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.db_enrichment_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.db_enrichment_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.db_scan_reaper](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.db_scan_reaper_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.db_scan_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.db_scan_trigger_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.doc_cleanup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.doc_cleanup_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.doc_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.doc_trigger_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.federated_catalog](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.federation_provisioner](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.federation_provisioner_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.glue_event_rescan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.glue_event_rescan_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.kg_build_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.kg_build_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lakeformation_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lakeformation_admin_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.preprocessing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.preprocessing_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.rescan_scheduler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.sfn_db_scan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.sfn_doc_deletion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.sfn_doc_ingestion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.source_delete_worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.source_delete_worker_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.sources_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.sources_api_idempotency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.sources_api_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_event_source_mapping.bulk_review_worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_event_source_mapping.db_scan_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_event_source_mapping.doc_ingestion_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_event_source_mapping.glue_event_rescan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_event_source_mapping.source_delete](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_function.bulk_review_worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.db_connector](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.db_scan_reaper](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.db_scan_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.doc_cleanup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.doc_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.federation_provisioner](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.glue_event_rescan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.lakeformation_admin](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.preprocessing](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.source_delete_worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.sources_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.db_scan_reaper_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_opensearchserverless_access_policy.sources_ingestion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_access_policy) | resource |
| [aws_s3_bucket.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.sources_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_cors_configuration.sources_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.sources_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.sources_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_ownership_controls.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.sources_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.sources_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.sources_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.sources_data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_scheduler_schedule_group.rescan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/scheduler_schedule_group) | resource |
| [aws_sfn_state_machine.db_scan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine) | resource |
| [aws_sfn_state_machine.doc_deletion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine) | resource |
| [aws_sfn_state_machine.doc_ingestion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine) | resource |
| [aws_sqs_queue.bulk_review](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.bulk_review_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.db_connector_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.db_scan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.db_scan_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.doc_ingestion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.doc_ingestion_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.glue_event](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.glue_event_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.source_delete](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.source_delete_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_policy.bulk_review](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_sqs_queue_policy.db_connector_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_sqs_queue_policy.glue_event](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_sqs_queue_policy.source_delete](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_sqs_queue_policy.tls_deny](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_ssm_parameter.db_connector_role_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.db_enrichment_role_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.db_scan_queue_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.db_scan_state_machine_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.doc_ingestion_queue_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.doc_ingestion_state_machine_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.federation_provisioner_role_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.source_scan_jobs_table_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.sources_api_fn_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.sources_table_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [terraform_data.lakeformation_admin_trigger](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aoss\_security\_group\_id | AOSS VPC endpoint security group ID (from network). Referenced by KG-build task role. | `string` | n/a | yes |
| athena\_results\_bucket\_arn | Athena query results bucket ARN (from storage). Referenced in the preprocessing DENY policy to prevent read access to platform-owned buckets. | `string` | n/a | yes |
| athena\_spill\_bucket\_arn | Athena federated connector spill bucket ARN (from storage). | `string` | n/a | yes |
| athena\_spill\_bucket\_name | Athena federated connector spill bucket name (from storage). | `string` | n/a | yes |
| connector\_security\_group\_id | Glue connector security group ID (from network). Applied to Glue Connections at runtime. | `string` | n/a | yes |
| db\_enrichment\_ecr\_repository\_url | ECR repository URL for the sources-db-enrichment image (from stack 25-ecr). | `string` | n/a | yes |
| discovery\_ocsp\_security\_group\_id | Dedicated OCSP-egress security group ID (from network). Attached as a SECOND SG on the sources-db-connector Lambda so its Snowflake driver can reach port-80 OCSP responders without granting that egress to every other Lambda on the shared lambda SG. | `string` | n/a | yes |
| ecs\_security\_group\_id | ECS Fargate task security group ID (from network). | `string` | n/a | yes |
| env | Deployment environment name. Gates prod retain-vs-destroy on S3 buckets. | `string` | n/a | yes |
| idempotency\_table\_arn | ARN of the shared idempotency-record DynamoDB table (from 10-foundation SSM /authnz/idempotency-table-arn). Create-operation Lambdas get Get/Put/Update/DeleteItem on it only. | `string` | n/a | yes |
| idempotency\_table\_name | Name of the shared idempotency-record DynamoDB table (from 10-foundation SSM /authnz/idempotency-table-name). Injected as IDEMPOTENCY\_TABLE for coa\_common.idempotency. | `string` | n/a | yes |
| kg\_build\_ecr\_repository\_url | ECR repository URL for the sources-doc-kg-build image (from stack 25-ecr). | `string` | n/a | yes |
| lakeformation\_admin\_zip\_path | Path to the built lakeformation-admin Lambda zip (produced by modules/services/sources/lambdas/lakeformation-admin/Makefile). | `string` | n/a | yes |
| lambda\_security\_group\_id | Lambda function security group ID (from network). | `string` | n/a | yes |
| logs\_kms\_key\_arn | CMK ARN for CloudWatch Logs encryption (from modules/foundation/kms, published to <ssm\_prefix>/kms/logs-key-arn). Applied to every aws\_cloudwatch\_log\_group in this module. | `string` | n/a | yes |
| name\_prefix | Physical resource name prefix (<resource\_prefix>-<env>). | `string` | n/a | yes |
| namespace\_tag\_key | Resource-tag key that binds JDBC credential secrets to authorized namespaces (e.g. `coa:namespace`). Derived from resource\_prefix; kept as an explicit input so the IAM conditions and runtime env vars cannot drift. | `string` | n/a | yes |
| namespaces\_table\_arn | Namespaces DDB table ARN (from namespace module). Read by discovery + enrichment for dataZoneProjectId lookups. | `string` | n/a | yes |
| namespaces\_table\_name | Namespaces DDB table name (from namespace module). | `string` | n/a | yes |
| neptune\_cluster\_arn | Neptune cluster resource ARN including trailing /* (from storage). | `string` | n/a | yes |
| neptune\_endpoint | Neptune cluster writer endpoint (from storage). | `string` | n/a | yes |
| ontology\_bucket\_arn | Ontology artifacts S3 bucket ARN (from storage). Doc-KG-build reads compiled ontology assets from here. | `string` | n/a | yes |
| opensearch\_collection\_arn | AOSS collection ARN (from storage). | `string` | n/a | yes |
| opensearch\_collection\_name | AOSS collection name (from storage). | `string` | n/a | yes |
| opensearch\_endpoint | AOSS collection endpoint (from storage). | `string` | n/a | yes |
| preprocessing\_ecr\_repository\_url | ECR repository URL for the sources-doc-preprocessing image (from stack 25-ecr). | `string` | n/a | yes |
| private\_subnet\_ids | Private subnet IDs (from network). | `list(string)` | n/a | yes |
| region | AWS region. | `string` | n/a | yes |
| resource\_prefix | Bare resource prefix (e.g. `coa`) without env suffix. Used to derive the sanitized federation catalog prefix and the namespace tag key. | `string` | n/a | yes |
| smus\_domain\_id | DataZone/SMUS domain ID (from namespace). | `string` | n/a | yes |
| smus\_project\_access\_role\_arn | Shared DataZone project access role ARN (from namespace). Discovery and enrichment task roles assume it for DataZone catalog writes. | `string` | n/a | yes |
| sources\_db\_trigger\_zip\_path | Path to the built db-scan-trigger Lambda zip (minimal, just the trigger source). Produced by modules/services/sources/lambdas/sources-db-trigger/Makefile. | `string` | n/a | yes |
| sources\_doc\_cleanup\_zip\_path | Path to the built doc-cleanup Lambda zip. Produced by modules/services/sources/lambdas/sources-doc-cleanup/Makefile. | `string` | n/a | yes |
| sources\_doc\_trigger\_zip\_path | Path to the built doc-ingestion-trigger Lambda zip. Produced by modules/services/sources/lambdas/sources-doc-trigger/Makefile. | `string` | n/a | yes |
| sources\_zip\_path | Path to the built shared sources Lambda zip (superset used by dbConnector, federationProvisioner, dbScanReaper, bulkReviewWorker, sourcesApi). Produced by modules/services/sources/lambdas/sources/Makefile. | `string` | n/a | yes |
| ssm\_prefix | SSM parameter root (e.g. /coa). | `string` | n/a | yes |
| vpc\_id | VPC ID (from network). | `string` | n/a | yes |
| allowed\_origin | CORS allowed origin for the sources-data bucket presigned uploads. | `string` | `"*"` | no |
| bedrock\_chat\_model\_id | Bedrock chat/completion model ID used by the database-enrichment task. Also drives the bedrockModelArn output that scopes the task role's Bedrock IAM. | `string` | `"us.anthropic.claude-haiku-4-5-20251001-v1:0"` | no |
| bedrock\_embed\_dimensions | Embedding vector dimensions for the doc-KG-build container's embedding model. Must equal the value the AOSS index was created with. | `number` | `1024` | no |
| bedrock\_embed\_model\_id | Bedrock embedding model ID for doc-KG-build. MUST match what serve queries with (vectors from different models are incomparable). | `string` | `"us.cohere.embed-v4:0"` | no |
| cdk\_cfn\_exec\_role\_name | Optional CloudFormation execution role name to allowlist in the Databricks parameter-audit metric filter. When null, only the sources-API role is allowlisted. Set only when a stack managed via CDK/CloudFormation legitimately writes under the Databricks per-source parameter prefix; most Terraform-only deployments leave this null. | `string` | `null` | no |
| component | Component tag applied to every resource in this module. | `string` | `"sources"` | no |
| db\_enrichment\_image\_tag\_file | Path to artifacts/images/sources-db-enrichment.tag containing the pushed ECR image URI. When null, the URI falls back to `<ecr_repo>:latest`. | `string` | `null` | no |
| db\_scan\_enrichment\_timeout\_minutes | Catchable per-task timeout on the enrichment ECS step in the dbScan Step Function. States.Timeout is caught → SCAN\_FAILED. The state-machine timeout is this + 2 min so the catchable path always fires first. | `number` | `120` | no |
| kg\_build\_image\_tag\_file | Path to artifacts/images/sources-kg-build.tag containing the pushed ECR image URI. When null, the URI falls back to `<ecr_repo>:latest`. | `string` | `null` | no |
| lambda\_reserved\_concurrency | Reserved concurrency for the preprocessing DockerImageFunction. Caps document-preprocessing fan-out. 0 omits the reservation (required on reduced-quota accounts). | `number` | `5` | no |
| preprocessing\_image\_tag\_file | Path to artifacts/images/sources-preprocessing.tag containing the pushed ECR image URI for the preprocessing DockerImageFunction. When null, falls back to `<ecr_repo>:latest`. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| batch\_inference\_role\_arn | Bedrock batch inference service role ARN (passed to the kg-build task for batch model-invocation jobs). |
| bulk\_review\_dlq\_arn | ARN of the bulk-review DLQ. |
| bulk\_review\_queue\_arn | ARN of the bulk-review queue. |
| bulk\_review\_queue\_url | URL of the bulk-review queue. |
| bulk\_review\_worker\_fn\_arn | Bulk review worker Lambda ARN (async ApproveSource/RejectSource). |
| db\_connector\_dlq\_arn | ARN of the discovery Lambda's Lambda-native DLQ. |
| db\_connector\_fn\_arn | Discovery Lambda ARN. |
| db\_enrichment\_cluster\_arn | ECS cluster ARN hosting the database enrichment task. |
| db\_enrichment\_task\_definition\_family | Family of the database enrichment Fargate task definition. |
| db\_scan\_dlq\_arn | ARN of the db-scan DLQ. |
| db\_scan\_queue\_arn | ARN of the db-scan queue (feeds the SFN via the trigger Lambda). |
| db\_scan\_queue\_url | URL of the db-scan queue. |
| db\_scan\_reaper\_fn\_arn | Terminal-status safety-net reaper Lambda ARN. |
| db\_scan\_state\_machine\_arn | dbScan Step Functions state machine ARN. |
| db\_scan\_trigger\_fn\_arn | SQS→SFN trigger Lambda ARN. |
| doc\_cleanup\_fn\_arn | Doc cleanup Lambda ARN (S3 + DDB cleanup on document source deletion). |
| doc\_deletion\_state\_machine\_arn | Doc deletion Step Functions state machine ARN. |
| doc\_ingestion\_dlq\_arn | ARN of the doc-ingestion DLQ. |
| doc\_ingestion\_queue\_arn | ARN of the doc-ingestion queue (feeds the SFN via the trigger Lambda). |
| doc\_ingestion\_queue\_url | URL of the doc-ingestion queue. |
| doc\_ingestion\_state\_machine\_arn | Doc ingestion Step Functions state machine ARN. |
| doc\_trigger\_fn\_arn | SQS → doc-ingestion SFN trigger Lambda ARN. |
| federation\_provisioner\_fn\_arn | Federation provisioner Lambda ARN. |
| federation\_provisioner\_role\_arn | Federation provisioner IAM role ARN. Sub-turn 4 registers this as a Lake Formation data-lake admin. |
| kg\_build\_cluster\_arn | ECS cluster ARN hosting the doc-kg-build task (with Container Insights v2). |
| kg\_build\_task\_definition\_family | Family of the doc-kg-build Fargate task definition. |
| preprocessing\_fn\_arn | Doc preprocessing DockerImageFunction ARN. |
| source\_scan\_jobs\_table\_arn | source-scan-jobs DDB table ARN. |
| source\_scan\_jobs\_table\_name | source-scan-jobs DDB table name. |
| sources\_access\_logs\_bucket\_arn | Access logs bucket ARN (shared logging target for the sources-data bucket). |
| sources\_api\_fn\_arn | Unified sources API Lambda ARN. Downstream API stack points to this for the /namespaces/*/sources/* routes. |
| sources\_api\_fn\_name | Unified sources API Lambda function name. |
| sources\_api\_role\_arn | Sources API Lambda execution role ARN. The namespace deletion pipeline's DeleteSources Lambda invokes the sources API by function ARN, but callers that need to grant sources-api additional permissions bind against this role. |
| sources\_bucket\_arn | sources-data S3 bucket ARN. |
| sources\_bucket\_name | sources-data S3 bucket name. |
| sources\_table\_arn | sources DDB table ARN. |
| sources\_table\_name | sources DDB table name. |
<!-- END_TF_DOCS -->
