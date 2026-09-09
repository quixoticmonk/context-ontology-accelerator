# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# All alarms scoped to Warning severity (matches SclMonitoring in the
# CDK — round one is Warning only; a Critical band + on-call routing
# comes later).

# ═════════════════════════════════════════════════════════════════════
#  Lambda — 2 alarms per function (Errors, Throttles)
# ═════════════════════════════════════════════════════════════════════

resource "aws_cloudwatch_metric_alarm" "lambda_faults" {
  for_each = var.lambda_names

  alarm_name          = "${var.alarm_name_prefix}-lambda-${each.value}-faults-warning"
  alarm_description   = "Lambda ${each.value}: fault count above ${local.lambda_max_faults} for 1 datapoint."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = local.lambda_max_faults
  treat_missing_data  = "notBreaching"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"

  dimensions = {
    FunctionName = each.value
  }

  actions_enabled = true
  alarm_actions   = local.alarm_actions
  ok_actions      = local.alarm_actions

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  for_each = var.lambda_names

  alarm_name          = "${var.alarm_name_prefix}-lambda-${each.value}-throttles-warning"
  alarm_description   = "Lambda ${each.value}: throttle count above ${local.lambda_max_throttles} for 1 datapoint."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = local.lambda_max_throttles
  treat_missing_data  = "notBreaching"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"

  dimensions = {
    FunctionName = each.value
  }

  actions_enabled = true
  alarm_actions   = local.alarm_actions
  ok_actions      = local.alarm_actions

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  API Gateway — 2 alarms per REST API (P99 latency, 5XX)
# ═════════════════════════════════════════════════════════════════════

resource "aws_cloudwatch_metric_alarm" "api_latency_p99" {
  for_each = var.rest_api_names

  alarm_name          = "${var.alarm_name_prefix}-api-${each.value}-p99-warning"
  alarm_description   = "REST API ${each.value}: P99 latency above ${local.api_p99_latency_seconds}s."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  # ApiGateway Latency is milliseconds
  threshold          = local.api_p99_latency_seconds * 1000
  treat_missing_data = "notBreaching"
  metric_name        = "Latency"
  namespace          = "AWS/ApiGateway"
  period             = 60
  extended_statistic = "p99"

  dimensions = {
    ApiName = each.value
  }

  actions_enabled = true
  alarm_actions   = local.alarm_actions
  ok_actions      = local.alarm_actions

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  for_each = var.rest_api_names

  alarm_name          = "${var.alarm_name_prefix}-api-${each.value}-5xx-warning"
  alarm_description   = "REST API ${each.value}: 5XX fault count above ${local.api_max_5xx}."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = local.api_max_5xx
  treat_missing_data  = "notBreaching"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "Sum"

  dimensions = {
    ApiName = each.value
  }

  actions_enabled = true
  alarm_actions   = local.alarm_actions
  ok_actions      = local.alarm_actions

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  DynamoDB — 3 alarms per table (read-throttled, write-throttled, sys-err)
# ═════════════════════════════════════════════════════════════════════

resource "aws_cloudwatch_metric_alarm" "ddb_read_throttled" {
  for_each = var.dynamodb_table_names

  alarm_name          = "${var.alarm_name_prefix}-ddb-${each.value}-read-throttled-warning"
  alarm_description   = "DDB table ${each.value}: read-throttled events above ${local.table_max_throttled}."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = local.table_max_throttled
  treat_missing_data  = "notBreaching"
  metric_name         = "ReadThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"

  dimensions = {
    TableName = each.value
  }

  actions_enabled = true
  alarm_actions   = local.alarm_actions
  ok_actions      = local.alarm_actions

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "ddb_write_throttled" {
  for_each = var.dynamodb_table_names

  alarm_name          = "${var.alarm_name_prefix}-ddb-${each.value}-write-throttled-warning"
  alarm_description   = "DDB table ${each.value}: write-throttled events above ${local.table_max_throttled}."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = local.table_max_throttled
  treat_missing_data  = "notBreaching"
  metric_name         = "WriteThrottleEvents"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"

  dimensions = {
    TableName = each.value
  }

  actions_enabled = true
  alarm_actions   = local.alarm_actions
  ok_actions      = local.alarm_actions

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "ddb_system_errors" {
  for_each = var.dynamodb_table_names

  alarm_name          = "${var.alarm_name_prefix}-ddb-${each.value}-system-errors-warning"
  alarm_description   = "DDB table ${each.value}: system errors above ${local.table_max_system_errors}."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = local.table_max_system_errors
  treat_missing_data  = "notBreaching"
  metric_name         = "SystemErrors"
  namespace           = "AWS/DynamoDB"
  period              = 60
  statistic           = "Sum"

  dimensions = {
    TableName = each.value
  }

  actions_enabled = true
  alarm_actions   = local.alarm_actions
  ok_actions      = local.alarm_actions

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  SQS DLQ — one alarm per DLQ on ApproximateNumberOfMessagesVisible
# ═════════════════════════════════════════════════════════════════════

resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  for_each = local.dlq_queue_names

  alarm_name          = "${var.alarm_name_prefix}-dlq-${each.value}-messages-warning"
  alarm_description   = "DLQ ${each.value}: ApproximateNumberOfMessagesVisible above ${local.dlq_max_messages}."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = local.dlq_max_messages
  treat_missing_data  = "notBreaching"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Maximum"

  dimensions = {
    QueueName = each.value
  }

  actions_enabled = true
  alarm_actions   = local.alarm_actions
  ok_actions      = local.alarm_actions

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  Step Functions — one alarm per state machine on ExecutionsFailed
# ═════════════════════════════════════════════════════════════════════

resource "aws_cloudwatch_metric_alarm" "sfn_failed" {
  for_each = local.state_machine_names

  alarm_name          = "${var.alarm_name_prefix}-sfn-${each.value}-failed-warning"
  alarm_description   = "State machine ${each.value}: ExecutionsFailed above ${local.sfn_max_failed}."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = local.sfn_max_failed
  treat_missing_data  = "notBreaching"
  metric_name         = "ExecutionsFailed"
  namespace           = "AWS/States"
  period              = 60
  statistic           = "Sum"

  dimensions = {
    StateMachineArn = each.key
  }

  actions_enabled = true
  alarm_actions   = local.alarm_actions
  ok_actions      = local.alarm_actions

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  ECS Fargate services — CPU + Memory average alarms per service
# ═════════════════════════════════════════════════════════════════════

resource "aws_cloudwatch_metric_alarm" "fargate_cpu" {
  for_each = var.fargate_services

  alarm_name          = "${var.alarm_name_prefix}-ecs-${each.key}-cpu-warning"
  alarm_description   = "ECS Fargate service ${each.key}: CPU utilization above ${local.ecs_max_cpu_percent}%."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = local.ecs_max_cpu_percent
  treat_missing_data  = "notBreaching"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"

  dimensions = {
    ClusterName = each.value.cluster_name
    ServiceName = each.value.service_name
  }

  actions_enabled = true
  alarm_actions   = local.alarm_actions
  ok_actions      = local.alarm_actions

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "fargate_memory" {
  for_each = var.fargate_services

  alarm_name          = "${var.alarm_name_prefix}-ecs-${each.key}-memory-warning"
  alarm_description   = "ECS Fargate service ${each.key}: memory utilization above ${local.ecs_max_mem_percent}%."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = local.ecs_max_mem_percent
  treat_missing_data  = "notBreaching"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"

  dimensions = {
    ClusterName = each.value.cluster_name
    ServiceName = each.value.service_name
  }

  actions_enabled = true
  alarm_actions   = local.alarm_actions
  ok_actions      = local.alarm_actions

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  ECS cluster-level — CPU max + Memory avg (VKG-style dynamic services)
# ═════════════════════════════════════════════════════════════════════

resource "aws_cloudwatch_metric_alarm" "cluster_cpu" {
  for_each = var.ecs_cluster_only_names

  alarm_name          = "${var.alarm_name_prefix}-ecs-cluster-${each.value}-cpu-warning"
  alarm_description   = "ECS cluster ${each.value}: max CPU utilization above ${local.ecs_max_cpu_percent}% for 3 periods."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = local.ecs_max_cpu_percent
  treat_missing_data  = "notBreaching"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Maximum"

  dimensions = {
    ClusterName = each.value
  }

  actions_enabled = true
  alarm_actions   = local.alarm_actions
  ok_actions      = local.alarm_actions

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "cluster_memory" {
  for_each = var.ecs_cluster_only_names

  alarm_name          = "${var.alarm_name_prefix}-ecs-cluster-${each.value}-memory-warning"
  alarm_description   = "ECS cluster ${each.value}: avg memory utilization above ${local.ecs_max_mem_percent}% for 3 periods."
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = local.ecs_max_mem_percent
  treat_missing_data  = "notBreaching"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"

  dimensions = {
    ClusterName = each.value
  }

  actions_enabled = true
  alarm_actions   = local.alarm_actions
  ok_actions      = local.alarm_actions

  tags = local.tags
}
