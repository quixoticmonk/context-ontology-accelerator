# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "alarm_name_prefix" {
  description = "Prefix on every alarm name. Matches CDK `SclMonitoring.alarmNamePrefix` (typically `<resource_prefix>-<env>`)."
  type        = string
}

variable "alarm_topic_arn" {
  description = "Optional SNS topic ARN wired to every alarm's alarm_actions (and ok_actions). When null the alarms are action-ready but route nowhere — this matches CDK round-one, where actionsEnabled=true but no strategy is bound yet."
  type        = string
  default     = null
}

variable "component" {
  description = "Component tag."
  type        = string
  default     = "observability"
}

variable "dlq_arns" {
  description = "Set of dead-letter queue ARNs. Emits one alarm per DLQ on ApproximateNumberOfMessagesVisible > 1. Matches CDK monitorQueueWithDlq()."
  type        = set(string)
  default     = []
}

variable "dynamodb_table_names" {
  description = "Set of DynamoDB table names. Emits three alarms per table: read-throttled events, write-throttled events, and system errors > 1. Matches CDK monitorTable()."
  type        = set(string)
  default     = []
}

variable "ecs_cluster_only_names" {
  description = "Set of ECS cluster names monitored at the cluster level (used where a stack runs an ECS cluster with runtime-created services, e.g. VKG). Emits CPU-max and Memory-avg alarms per cluster. Matches CDK monitorClusterCpuMem()."
  type        = set(string)
  default     = []
}

variable "fargate_services" {
  description = "Map of alarm-friendly-name => { cluster_name, service_name } to monitor as ECS Fargate services. Emits CPU and Memory average alarms per service. Matches CDK monitorFargateService()."
  type = map(object({
    cluster_name = string
    service_name = string
  }))
  default = {}
}

variable "lambda_names" {
  description = "Set of Lambda function names. Emits two alarms per Lambda: Errors > 1 and Throttles > 1. Matches CDK monitorLambda()."
  type        = set(string)
  default     = []
}

variable "rest_api_names" {
  description = "Set of REST API names (ApiName dimension in AWS/ApiGateway). Emits two alarms per API: Latency P99 > 5s and 5XXError > 1. Matches CDK monitorApi()."
  type        = set(string)
  default     = []
}

variable "state_machine_arns" {
  description = "Set of Step Functions state machine ARNs. Emits one alarm per SM on ExecutionsFailed > 1. Matches CDK monitorStateMachine()."
  type        = set(string)
  default     = []
}
