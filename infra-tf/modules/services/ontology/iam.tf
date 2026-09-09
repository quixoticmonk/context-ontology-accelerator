# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IAM for the ontology-engine ECS task:
#   1. execution role — pulls the image + writes container logs
#      (AWS-managed AmazonECSTaskExecutionRolePolicy)
#   2. task role      — the container's runtime identity, granted every
#      downstream permission the CDK attaches to taskDef.taskRole
#
# The API proxy Lambda's role lives with the function (api_lambda.tf).

# ════════════════════════════════════════════════════════════════════
#  Shared ecs-tasks trust policy
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

# ════════════════════════════════════════════════════════════════════
#  1. Task execution role
# ════════════════════════════════════════════════════════════════════
resource "aws_iam_role" "execution" {
  name               = "${local.task_family}-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ════════════════════════════════════════════════════════════════════
#  2. Task role
# ════════════════════════════════════════════════════════════════════
resource "aws_iam_role" "task" {
  name               = "${local.task_family}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
  tags               = local.tags
}

data "aws_iam_policy_document" "task" {
  # ── Neptune DB — read/write/delete via SPARQL + Graph Store Protocol
  # neptune_cluster_arn already carries the trailing /* (gotcha #2) —
  # used verbatim, no extra suffix.
  statement {
    sid = "NeptuneData"
    actions = [
      "neptune-db:ReadDataViaQuery",
      "neptune-db:WriteDataViaQuery",
      "neptune-db:DeleteDataViaQuery",
      "neptune-db:GetQueryStatus",
      "neptune-db:CancelQuery",
    ]
    resources = [var.neptune_cluster_arn]
  }

  # ── OpenSearch Serverless — API access (paired with the data-access
  # policy in main.tf; gotcha #3 — both are required).
  statement {
    sid       = "AossApiAccess"
    actions   = ["aoss:APIAccessAll"]
    resources = [var.opensearch_collection_arn]
  }

  # ── DynamoDB — full R/W on own table + read on namespaces + sources.
  statement {
    sid = "DynamoDbOwnTable"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:ConditionCheckItem",
      "dynamodb:DescribeTable",
    ]
    resources = [
      aws_dynamodb_table.this.arn,
      "${aws_dynamodb_table.this.arn}/index/*",
    ]
  }

  statement {
    sid     = "DynamoDbCrossTableRead"
    actions = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:BatchGetItem", "dynamodb:DescribeTable"]
    resources = [
      "arn:${data.aws_partition.current.partition}:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.namespaces_table_name}",
      "arn:${data.aws_partition.current.partition}:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.namespaces_table_name}/index/*",
      "arn:${data.aws_partition.current.partition}:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.sources_table_name}",
      "arn:${data.aws_partition.current.partition}:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.sources_table_name}/index/*",
    ]
  }

  # ── S3 — read+write ontology artifacts (Turtle, R2RML).
  statement {
    sid       = "S3ObjectRw"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:GetObjectVersion"]
    resources = ["${var.ontology_bucket_arn}/*"]
  }

  statement {
    sid       = "S3BucketList"
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [var.ontology_bucket_arn]
  }

  # ── Bedrock — LLM (Converse) + Embeddings (InvokeModel) + guardrail.
  # Scoped to the configured models' inference-profile + underlying
  # foundation-model ARNs (gotcha #1), plus the guardrail namespace.
  statement {
    sid = "BedrockInvoke"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:Converse",
      "bedrock:ApplyGuardrail",
    ]
    resources = concat(
      local.inference_profile_arns,
      local.foundation_model_arns,
      ["arn:${data.aws_partition.current.partition}:bedrock:${var.region}:${data.aws_caller_identity.current.account_id}:guardrail/*"],
    )
  }

  # ── AWS Marketplace — first-time Bedrock model subscription handshake
  # (issue #814). No resource-level ARN exists for these actions.
  statement {
    sid       = "MarketplaceSubscribe"
    actions   = ["aws-marketplace:ViewSubscriptions", "aws-marketplace:Subscribe"]
    resources = ["*"]
  }

  # ── SSM — read the Bedrock guardrail id at runtime.
  statement {
    sid       = "SsmGuardrail"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:${data.aws_partition.current.partition}:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_prefix}/bedrock/guardrail-id"]
  }

  # ── DataZone/SMUS — read catalog metadata, scoped to the one domain.
  statement {
    sid = "DataZoneRead"
    actions = [
      "datazone:GetAsset",
      "datazone:SearchAssets",
      "datazone:Search",
      "datazone:GetProject",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:datazone:${var.region}:${data.aws_caller_identity.current.account_id}:domain/${var.smus_domain_id}",
      "arn:${data.aws_partition.current.partition}:datazone:${var.region}:${data.aws_caller_identity.current.account_id}:domain/${var.smus_domain_id}/*",
    ]
  }

  # ── STS — assume the DataZone project-access role (project membership
  # gates DataZone reads, not IAM alone).
  statement {
    sid       = "AssumeProjectAccessRole"
    actions   = ["sts:AssumeRole"]
    resources = [var.smus_project_access_role_arn]
  }

  # ── Lambda — invoke the sources-api for catalog column fetching.
  statement {
    sid       = "InvokeSourcesApi"
    actions   = ["lambda:InvokeFunction"]
    resources = ["arn:${data.aws_partition.current.partition}:lambda:${var.region}:${data.aws_caller_identity.current.account_id}:function:${local.sources_api_fn_name}"]
  }

  # ── EventBridge — emit ontology.published events for VKG reload.
  statement {
    sid       = "PutEvents"
    actions   = ["events:PutEvents"]
    resources = ["arn:${data.aws_partition.current.partition}:events:${var.region}:${data.aws_caller_identity.current.account_id}:event-bus/default"]
  }

  # ── CloudWatch — publish custom induction/guardrail metrics. No
  # resource-level ARN; least privilege via the namespace condition key.
  statement {
    sid       = "PutMetricData"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["COA/Ontology", "COA/Guardrails"]
    }
  }
}

resource "aws_iam_policy" "task" {
  name   = "${local.task_family}-task-policy"
  policy = data.aws_iam_policy_document.task.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "task" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task.arn
}
