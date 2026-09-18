# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# VKG infrastructure — ECR repo, ECS cluster + task-definition template,
# reload automation (EventBridge -> Lambda), and SSM writes.
#
# Per-namespace VKG services are provisioned dynamically by the reload
# Lambda when an ontology is published. No static "default" service is
# deployed here — VKG instances only exist for namespaces with a
# published ontology. This module owns the shared cluster, the task
# definition template, and the reload Lambda. IAM lives in iam.tf.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ════════════════════════════════════════════════════════════════════
#  CloudWatch log group (task-definition template log config)
# ════════════════════════════════════════════════════════════════════

resource "aws_cloudwatch_log_group" "this" {
  # checkov:skip=CKV_AWS_338:30-day retention is the current operational minimum for this non-regulated workload. Bump to >= 365 if compliance requirements change.
  name              = local.log_group_name
  retention_in_days = 30
  kms_key_id        = var.logs_kms_key_arn

  tags = local.tags
}

# ════════════════════════════════════════════════════════════════════
#  ECS cluster (no default service)
# ════════════════════════════════════════════════════════════════════

resource "aws_ecs_cluster" "this" {
  name = local.cluster_name

  tags = local.tags
}

# ════════════════════════════════════════════════════════════════════
#  Task-definition template
# ════════════════════════════════════════════════════════════════════
# A template only — the reload Lambda registers its own per-namespace
# revisions at runtime. This definition anchors the image URI (source of
# truth via SSM), roles, port, and log config.

resource "aws_ecs_task_definition" "this" {
  family                   = local.task_family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory_limit_mib
  task_role_arn            = aws_iam_role.task.arn
  execution_role_arn       = aws_iam_role.execution.arn

  runtime_platform {
    # ARM64 across the module: matches the CDK task-def template
    # (which is also ARM64) AND matches the reload Lambda's
    # `_register_task_definition()` in infra/lambda/vkg-reload/index.py,
    # which hardcodes ARM64 for the per-namespace task defs it creates
    # at runtime. Also matches the image Makefile's --platform linux/arm64.
    # All three must agree, or ECS fails to start tasks with an
    # architecture-mismatch error.
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = local.image_uri
      essential = true

      environment = [
        { name = "ONTOLOGY_BUCKET", value = var.ontology_bucket_name },
        { name = "ONTOLOGY_PREFIX", value = "ontologies/" },
        { name = "ENDPOINT_PORT", value = tostring(var.container_port) },
        # ONTOP_JAVA_ARGS, NOT JAVA_OPTS — the Ontop launcher ignores
        # JAVA_OPTS entirely (#149 cause C). Derived in locals.tf from
        # memory_limit_mib so raising memory alone scales the heap.
        { name = "ONTOP_JAVA_ARGS", value = local.ontop_java_args },
      ]

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        },
      ]

      healthCheck = {
        command     = ["CMD-SHELL", "curl -sf http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 5
        startPeriod = 180
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "vkg"
        }
      }
    },
  ])

  tags = local.tags
}

# ════════════════════════════════════════════════════════════════════
#  VPC ingress for the container port
# ════════════════════════════════════════════════════════════════════
# Per-namespace VKG services share the ECS security group; allow inbound
# SPARQL translation on the container port from within the VPC.

data "aws_vpc" "this" {
  id = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "vkg_from_vpc" {
  security_group_id = var.ecs_security_group_id
  cidr_ipv4         = data.aws_vpc.this.cidr_block
  ip_protocol       = "tcp"
  from_port         = var.container_port
  to_port           = var.container_port
  description       = "Allow VKG SPARQL translation from VPC"

  tags = local.tags
}

# ════════════════════════════════════════════════════════════════════
#  Reload Lambda (EventBridge -> ECS)
# ════════════════════════════════════════════════════════════════════

resource "aws_lambda_function" "reload" {
  function_name                  = local.reload_fn_name
  role                           = aws_iam_role.reload.arn
  runtime                        = "python3.12"
  handler                        = "index.handler"
  filename                       = var.vkg_reload_zip_path
  source_code_hash               = local.reload_zip_hash
  timeout                        = 30
  reserved_concurrent_executions = local.reserved_concurrency

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.ecs_security_group_id]
  }

  environment {
    variables = {
      CLUSTER_ARN            = aws_ecs_cluster.this.arn
      RESOURCE_PREFIX        = var.name_prefix
      CLOUD_MAP_NAMESPACE_ID = var.service_namespace_id
      VKG_TASK_ROLE_ARN      = aws_iam_role.task.arn
      VKG_EXECUTION_ROLE_ARN = aws_iam_role.execution.arn
      ONTOLOGY_BUCKET        = var.ontology_bucket_name
      PRIVATE_SUBNET_IDS     = join(",", var.private_subnet_ids)
      ECS_SECURITY_GROUP_ID  = var.ecs_security_group_id
      VKG_IMAGE_PARAM_NAME   = aws_ssm_parameter.container_image.name
    }
  }

  tags = local.tags
}

resource "aws_lambda_permission" "reload_from_events" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reload.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ontology_published.arn
}

resource "aws_lambda_permission" "reload_from_sweep" {
  statement_id  = "AllowEventBridgeSweepInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.reload.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.reload_sweep.arn
}

# ── EventBridge: ontology.published -> per-namespace reload ─────────
resource "aws_cloudwatch_event_rule" "ontology_published" {
  name = local.reload_rule

  event_pattern = jsonencode({
    source      = [local.event_source]
    detail-type = ["ontology.published"]
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "ontology_published" {
  rule      = aws_cloudwatch_event_rule.ontology_published.name
  target_id = "VkgReload"
  arn       = aws_lambda_function.reload.arn

  retry_policy {
    maximum_event_age_in_seconds = 300
    maximum_retry_attempts       = 2
  }
}

# ── EventBridge: weekly sweep -> reconcile every service to SSM image ─
resource "aws_cloudwatch_event_rule" "reload_sweep" {
  name                = local.reload_sweep
  schedule_expression = "rate(7 days)"

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "reload_sweep" {
  rule      = aws_cloudwatch_event_rule.reload_sweep.name
  target_id = "VkgReloadSweep"
  arn       = aws_lambda_function.reload.arn
  input     = jsonencode({ sweep = true })
}

# ════════════════════════════════════════════════════════════════════
#  Reload-failure alarm
# ════════════════════════════════════════════════════════════════════
# Alarms on the undimensioned ReloadFailed roll-up the reload Lambda
# emits (a metric alarm cannot be backed by a SEARCH() expression, so it
# must evaluate a concrete series fed by every namespace).

resource "aws_cloudwatch_metric_alarm" "reload_failed" {
  alarm_name          = local.metric_alarm
  alarm_description   = "VKG ontology reload failed - the namespace may be serving stale or unavailable results"
  namespace           = "COA/VKG"
  metric_name         = "ReloadFailed"
  statistic           = "Sum"
  period              = 300
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  treat_missing_data  = "notBreaching"

  tags = local.tags
}

# ════════════════════════════════════════════════════════════════════
#  SSM writes
# ════════════════════════════════════════════════════════════════════

resource "aws_ssm_parameter" "cluster_arn" {
  name        = "${var.ssm_prefix}/vkg/cluster-arn"
  type        = "String"
  value       = aws_ecs_cluster.this.arn
  description = "VKG ECS cluster ARN"
  tags        = local.tags
}

resource "aws_ssm_parameter" "cluster_name" {
  name        = "${var.ssm_prefix}/vkg/cluster-name"
  type        = "String"
  value       = aws_ecs_cluster.this.name
  description = "VKG ECS cluster name"
  tags        = local.tags
}

resource "aws_ssm_parameter" "task_definition_family" {
  name        = "${var.ssm_prefix}/vkg/task-definition-family"
  type        = "String"
  value       = aws_ecs_task_definition.this.family
  description = "VKG task-definition family (reload Lambda registers per-namespace revisions under a derived family)"
  tags        = local.tags
}

resource "aws_ssm_parameter" "container_port" {
  name        = "${var.ssm_prefix}/vkg/container-port"
  type        = "String"
  value       = tostring(var.container_port)
  description = "VKG container port"
  tags        = local.tags
}

resource "aws_ssm_parameter" "service_namespace_id" {
  name        = "${var.ssm_prefix}/vkg/service-namespace-id"
  type        = "String"
  value       = var.service_namespace_id
  description = "Cloud Map namespace ID for per-namespace VKG service registration"
  tags        = local.tags
}

resource "aws_ssm_parameter" "container_image" {
  name        = local.vkg_image_param
  type        = "String"
  value       = local.image_uri
  description = "Latest VKG container image URI (source of truth for the reload Lambda)"
  tags        = local.tags
}

resource "aws_ssm_parameter" "endpoint" {
  name        = "${var.ssm_prefix}/vkg/endpoint"
  type        = "String"
  value       = local.vkg_endpoint
  description = "VKG endpoint pattern (per-namespace services resolve as vkg-{ns}.domain:port)"
  tags        = local.tags
}
