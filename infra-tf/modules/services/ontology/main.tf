# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Ontology Engine service — induction, catalog, validation, and embedding
# management. This file holds the DynamoDB table, ECR repository, ECS log
# group, AOSS data-access policy, the ECS-from-Lambda ingress rule, and the
# SSM parameter writes. ECS/task-def live in ecs.tf, IAM in iam.tf, the API
# proxy Lambda in api_lambda.tf, and Cloud Map discovery in cloudmap.tf.

# AWS-managed KMS key for DynamoDB (kms_key_arn on server_side_encryption
# is required by CKV_AWS_119 even when using the aws/dynamodb key). Making
# it explicit vs. relying on the default so intent is auditable.
data "aws_kms_alias" "dynamodb" {
  name = "alias/aws/dynamodb"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ════════════════════════════════════════════════════════════════════
#  DynamoDB table (single-table PK/SK design)
# ════════════════════════════════════════════════════════════════════
# Matches CDK OntologyEngineTable: PK/SK strings, PAY_PER_REQUEST,
# AWS-managed SSE, PITR enabled. No GSIs (the CDK table declares none).
resource "aws_dynamodb_table" "this" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = data.aws_kms_alias.dynamodb.target_key_arn
  }

  tags = local.tags
}

# ════════════════════════════════════════════════════════════════════
#  CloudWatch log group (ECS task)
# ════════════════════════════════════════════════════════════════════
resource "aws_cloudwatch_log_group" "ecs" {
  # checkov:skip=CKV_AWS_338:30-day retention is the current operational minimum for this non-regulated workload. Bump to >= 365 if compliance requirements change.
  name              = local.log_group
  retention_in_days = 30
  kms_key_id        = var.logs_kms_key_arn

  tags = local.tags
}

# ════════════════════════════════════════════════════════════════════
#  AOSS data-access policy (gotcha #3 — IAM action alone is insufficient)
# ════════════════════════════════════════════════════════════════════
# Names the ECS task role for full index CRUD on the shared collection.
# The ECS service depends on this (ecs.tf) so tasks do not race policy
# propagation and trip the deployment circuit breaker on a 403.
resource "aws_opensearchserverless_access_policy" "data" {
  name = local.oss_policy
  type = "data"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index"
          Resource     = ["index/${var.opensearch_collection_name}/*"]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DescribeIndex",
            "aoss:UpdateIndex",
            "aoss:DeleteIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument",
          ]
        },
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.opensearch_collection_name}"]
          Permission   = ["aoss:DescribeCollectionItems"]
        },
      ]
      Principal = [aws_iam_role.task.arn]
    },
  ])
}

# ════════════════════════════════════════════════════════════════════
#  ECS ingress from the API proxy Lambda
# ════════════════════════════════════════════════════════════════════
# CDK adds this ingress rule to the shared ECS SG so the api-proxy Lambda
# can reach the ontology-engine container on its port. Discrete v6-style
# rule (per style guide) referencing the two SGs passed in from network.
resource "aws_vpc_security_group_ingress_rule" "ecs_from_lambda" {
  security_group_id            = var.ecs_security_group_id
  referenced_security_group_id = var.lambda_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  description                  = "Allow ontology-engine API from api-proxy Lambda"

  tags = local.tags
}

# ════════════════════════════════════════════════════════════════════
#  SSM parameters (match CDK writes)
# ════════════════════════════════════════════════════════════════════
resource "aws_ssm_parameter" "cluster_arn" {
  name  = "${var.ssm_prefix}/ontology-engine/cluster-arn"
  type  = "String"
  value = aws_ecs_cluster.this.arn
  tags  = local.tags
}

resource "aws_ssm_parameter" "service_name" {
  name  = "${var.ssm_prefix}/ontology-engine/service-name"
  type  = "String"
  value = local.service_name
  tags  = local.tags
}

resource "aws_ssm_parameter" "service_namespace_arn" {
  name        = "${var.ssm_prefix}/ontology-engine/service-namespace-arn"
  type        = "String"
  value       = data.aws_service_discovery_dns_namespace.this.arn
  description = "Cloud Map private DNS namespace ARN (consumed by ontology services)"
  tags        = local.tags
}

resource "aws_ssm_parameter" "endpoint" {
  name  = "${var.ssm_prefix}/ontology-engine/endpoint"
  type  = "String"
  value = local.endpoint
  tags  = local.tags
}

resource "aws_ssm_parameter" "table_name" {
  name  = "${var.ssm_prefix}/ontology-engine/dynamodb-table"
  type  = "String"
  value = aws_dynamodb_table.this.name
  tags  = local.tags
}

resource "aws_ssm_parameter" "api_fn_arn" {
  name  = "${var.ssm_prefix}/ontology-engine/api-fn-arn"
  type  = "String"
  value = aws_lambda_function.api_proxy.arn
  tags  = local.tags
}
