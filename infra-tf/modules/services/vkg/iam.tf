# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IAM for the VKG module:
#   1. task      — ECS task role: S3 read on the ontology bucket
#   2. execution — ECS execution role: ECR pull + CloudWatch Logs
#   3. reload    — reload Lambda role: ECS/ServiceDiscovery/autoscaling
#                  provisioning + iam:PassRole on the task + execution roles
#
# Separate aws_iam_policy + aws_iam_role_policy_attachment per capability
# (no inline policies) per the style guide.

# ════════════════════════════════════════════════════════════════════
#  Trust policies
# ════════════════════════════════════════════════════════════════════

data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ════════════════════════════════════════════════════════════════════
#  1. Task role — S3 read on the ontology bucket
# ════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "task" {
  name               = "${var.name_prefix}-vkg-task-role"
  description        = "VKG ECS task role - reads compiled ontology + R2RML from the ontology bucket"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json

  tags = local.tags
}

data "aws_iam_policy_document" "task" {
  statement {
    sid       = "OntologyRead"
    actions   = ["s3:GetObject"]
    resources = ["${var.ontology_bucket_arn}/*"]
  }

  statement {
    sid       = "OntologyList"
    actions   = ["s3:ListBucket"]
    resources = [var.ontology_bucket_arn]
  }
}

resource "aws_iam_policy" "task" {
  name   = "${var.name_prefix}-vkg-task-policy"
  policy = data.aws_iam_policy_document.task.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "task" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task.arn
}

# ════════════════════════════════════════════════════════════════════
#  2. Execution role — ECR pull + CloudWatch Logs
# ════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "execution" {
  name               = "${var.name_prefix}-vkg-execution-role"
  description        = "VKG ECS execution role - ECR pull + CloudWatch Logs for per-namespace services"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Per-namespace VKG services log to /ecs/vkg-* groups the execution role
# must be able to create on first task launch.
data "aws_iam_policy_document" "execution_logs" {
  statement {
    sid = "VkgPerNamespaceLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/vkg-*",
      "arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/vkg-*:*",
    ]
  }
}

resource "aws_iam_policy" "execution_logs" {
  name   = "${var.name_prefix}-vkg-execution-logs-policy"
  policy = data.aws_iam_policy_document.execution_logs.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "execution_logs" {
  role       = aws_iam_role.execution.name
  policy_arn = aws_iam_policy.execution_logs.arn
}

# ════════════════════════════════════════════════════════════════════
#  3. Reload Lambda role
# ════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "reload" {
  name               = "${local.reload_fn_name}-role"
  description        = "VKG reload Lambda role - provisions per-namespace ECS services on ontology publish"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "reload_vpc" {
  role       = aws_iam_role.reload.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Reload Lambda policy. The residual `resources = ["*"]` statements
# are all AWS-service limitations, each with a scoping condition or a
# read-only shape:
#   • EcsListServices             — bounded by ecs:cluster condition
#   • EcsTaskDefinition           — no resource type per SAR; PassRole is bounded
#   • ServiceDiscoveryList        — API accepts no namespace arg; read-only
#   • ReloadMetrics               — bounded by cloudwatch:namespace = COA/VKG
# checkov:skip=CKV_AWS_356:Residual `*` is on actions AWS does not support resource-level for; each has a scoping condition where a condition key exists.
# checkov:skip=CKV_AWS_111:Write actions on `*` are constrained by cluster/namespace conditions or lack any AWS-supported resource type (per Service Authorization Reference).
data "aws_iam_policy_document" "reload" {
  # ECS service lifecycle scoped to this cluster's services.
  statement {
    sid = "EcsServiceLifecycle"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
      "ecs:CreateService",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:service/${aws_ecs_cluster.this.name}/*"]
  }

  # ListServices has no resource type; scope to this cluster via condition.
  statement {
    sid       = "EcsListServices"
    actions   = ["ecs:ListServices"]
    resources = ["*"]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [aws_ecs_cluster.this.arn]
    }
  }

  # Task-definition register/describe have no resource-level scoping.
  # `ecs:RegisterTaskDefinition` and `ecs:DescribeTaskDefinition` are
  # listed as "(not applicable)" for resource type in the AWS Service
  # Authorization Reference; IAM must be `*`. Blast radius is bounded
  # by the PassVkgRoles statement below — only the vkg-task and
  # vkg-execution roles can be attached to any registered task def.
  statement {
    sid       = "EcsTaskDefinition"
    actions   = ["ecs:RegisterTaskDefinition", "ecs:DescribeTaskDefinition"]
    resources = ["*"]
  }

  # PassRole the task + execution roles to ECS only.
  statement {
    sid       = "PassVkgRoles"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.task.arn, aws_iam_role.execution.arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  # Cloud Map service registration for per-namespace VKG services.
  # CreateService supports the `servicediscovery:NamespaceArn` condition
  # key — scoping to the Cloud Map namespace this module provisions
  # services under prevents the reload Lambda from creating services in
  # any other Cloud Map namespace.
  statement {
    sid       = "ServiceDiscoveryCreate"
    actions   = ["servicediscovery:CreateService"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "servicediscovery:NamespaceArn"
      values   = ["arn:${data.aws_partition.current.partition}:servicediscovery:${var.region}:${data.aws_caller_identity.current.account_id}:namespace/${var.service_namespace_id}"]
    }
  }

  # ListServices doesn't accept a namespace argument — the AWS-supplied
  # `servicediscovery:NamespaceArn` condition key isn't populated on
  # this call, so it cannot be constrained by IAM. Blast radius is
  # bounded: the returned data is only service metadata within this
  # account/region.
  statement {
    sid       = "ServiceDiscoveryList"
    actions   = ["servicediscovery:ListServices"]
    resources = ["*"]
  }

  # Application auto-scaling for per-namespace services. Scoped to
  # scalable-targets in this account/region and constrained to the ECS
  # service namespace so this role can't register autoscaling on
  # RDS/EMR/DynamoDB/etc. targets.
  statement {
    sid = "AutoScaling"
    actions = [
      "application-autoscaling:RegisterScalableTarget",
      "application-autoscaling:PutScalingPolicy",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:application-autoscaling:${var.region}:${data.aws_caller_identity.current.account_id}:scalable-target/*"]

    condition {
      test     = "StringEquals"
      variable = "application-autoscaling:service-namespace"
      values   = ["ecs"]
    }
  }

  # Per-namespace log-group management.
  statement {
    sid = "VkgLogs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/vkg-*",
      "arn:${data.aws_partition.current.partition}:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/vkg-*:*",
    ]
  }

  # Read the image-URI SSM parameter.
  statement {
    sid       = "ReadImageParam"
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.container_image.arn]
  }

  # PutMetricData has no resource-level scoping; restrict by namespace.
  statement {
    sid       = "ReloadMetrics"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["COA/VKG"]
    }
  }
}

resource "aws_iam_policy" "reload" {
  name   = "${local.reload_fn_name}-policy"
  policy = data.aws_iam_policy_document.reload.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "reload" {
  role       = aws_iam_role.reload.name
  policy_arn = aws_iam_policy.reload.arn
}
