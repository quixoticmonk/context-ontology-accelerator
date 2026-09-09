# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Stack 70 — Observability (CloudWatch alarms). Depends on all prior
# stacks having applied and written their SSM params so alarm keys are
# plan-known strings.

module "observability" {
  source = "../../modules/observability"

  alarm_name_prefix = local.name_prefix
  alarm_topic_arn   = var.alarm_topic_arn

  # aws_ssm_parameter marks .value sensitive. These are all plain
  # resource names/ARNs, not secrets. Unmark so for_each accepts them.
  lambda_names = nonsensitive(local.lambda_names)

  state_machine_arns = nonsensitive(toset([
    data.aws_ssm_parameter.sources_db_scan_state_machine_arn.value,
    data.aws_ssm_parameter.sources_doc_ingestion_state_machine_arn.value,
    data.aws_ssm_parameter.sources_doc_deletion_state_machine_arn.value,
  ]))

  dlq_arns = nonsensitive(toset([
    data.aws_ssm_parameter.sources_db_scan_dlq_arn.value,
    data.aws_ssm_parameter.sources_bulk_review_dlq_arn.value,
    data.aws_ssm_parameter.sources_doc_ingestion_dlq_arn.value,
    data.aws_ssm_parameter.metric_import_dlq_arn.value,
  ]))

  dynamodb_table_names = nonsensitive(toset([
    data.aws_ssm_parameter.metric_import_jobs_table_name.value,
    data.aws_ssm_parameter.ontology_dynamodb_table.value,
  ]))

  rest_api_names = toset([
    "${local.name_prefix}-api",
  ])

  fargate_services = {
    ontology_engine = {
      cluster_name = nonsensitive(data.aws_ssm_parameter.ontology_cluster_name.value)
      service_name = nonsensitive(data.aws_ssm_parameter.ontology_service_name.value)
    }
  }

  ecs_cluster_only_names = nonsensitive(toset([
    data.aws_ssm_parameter.vkg_cluster_name.value,
  ]))
}
