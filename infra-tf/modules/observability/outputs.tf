# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "alarm_count" {
  description = "Total number of alarms emitted by this module."
  value = (
    length(var.lambda_names) * 2 +
    length(var.rest_api_names) * 2 +
    length(var.dynamodb_table_names) * 3 +
    length(var.dlq_arns) +
    length(var.state_machine_arns) +
    length(var.fargate_services) * 2 +
    length(var.ecs_cluster_only_names) * 2
  )
}
