# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  tags = { Component = var.component }

  # Alarm action mapping — null topic yields no actions (action-ready-only)
  alarm_actions = var.alarm_topic_arn != null ? [var.alarm_topic_arn] : []

  # ── Thresholds match SclMonitoring in the CDK verbatim ──
  lambda_max_faults       = 1
  lambda_max_throttles    = 1
  api_p99_latency_seconds = 5
  api_max_5xx             = 1
  sfn_max_failed          = 1
  dlq_max_messages        = 1
  table_max_throttled     = 1
  table_max_system_errors = 1
  ecs_max_cpu_percent     = 90
  ecs_max_mem_percent     = 90

  # ── Derive names from ARNs ──
  # SFN ARN:  arn:aws:states:REGION:ACCOUNT:stateMachine:NAME     (idx 6)
  # SQS ARN:  arn:aws:sqs:REGION:ACCOUNT:NAME                     (idx 5)
  state_machine_names = { for arn in var.state_machine_arns : arn => element(split(":", arn), 6) }
  dlq_queue_names     = { for arn in var.dlq_arns : arn => element(split(":", arn), 5) }
}
