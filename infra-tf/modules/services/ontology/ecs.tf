# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# ECS Fargate: cluster, task definition (ontology-engine container), and
# the service with Cloud Map A-record registration. The CDK creates its
# OWN cluster (ecs.Cluster "OntologyCluster") rather than reusing a shared
# one, so this module does the same and exposes the cluster ARN as output.

# ════════════════════════════════════════════════════════════════════
#  ECS cluster
# ════════════════════════════════════════════════════════════════════
resource "aws_ecs_cluster" "this" {
  name = local.cluster_name

  tags = local.tags
}

# ════════════════════════════════════════════════════════════════════
#  Task definition
# ════════════════════════════════════════════════════════════════════
resource "aws_ecs_task_definition" "this" {
  family                   = local.task_family
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory_limit_mib
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = local.image_uri
      essential = true

      portMappings = [
        {
          containerPort = var.container_port
          protocol      = "tcp"
        },
      ]

      environment = [
        { name = "WORKBENCH_BACKEND", value = "opensearch_neptune" },
        { name = "NDB_ENDPOINT", value = "https://${var.neptune_endpoint}:8182" },
        { name = "NDB_IAM_AUTH", value = "true" },
        { name = "NDB_REGION", value = var.region },
        { name = "OSS_ENDPOINT", value = var.opensearch_endpoint },
        { name = "OSS_REGION", value = var.region },
        { name = "OSS_INDEX", value = var.opensearch_collection_name },
        { name = "OSS_DIMENSIONS", value = tostring(var.bedrock_embed_dimensions) },
        { name = "ONTOLOGY_ARTIFACTS_BUCKET", value = var.ontology_bucket_name },
        { name = "DYNAMODB_TABLE", value = aws_dynamodb_table.this.name },
        { name = "DYNAMODB_REGION", value = var.region },
        { name = "BEDROCK_REGION", value = var.region },
        { name = "BEDROCK_EMBED_MODEL_ID", value = var.bedrock_embed_model_id },
        { name = "BEDROCK_EMBED_DIMENSIONS", value = tostring(var.bedrock_embed_dimensions) },
        { name = "LLM_MODEL_ID", value = var.bedrock_induction_llm_model_id },
        { name = "DESCRIPTION_LLM_MODEL_ID", value = var.bedrock_induction_llm_model_id },
        { name = "BEDROCK_CHAT_MODEL_ID", value = var.bedrock_chat_model_id },
        { name = "LLM_REGION", value = var.region },
        { name = "GUARDRAIL_SSM_PARAM", value = "${var.ssm_prefix}/bedrock/guardrail-id" },
        { name = "CATALOG_SOURCE", value = "smus" },
        { name = "SMUS_DOMAIN_ID", value = var.smus_domain_id },
        { name = "NAMESPACES_TABLE", value = var.namespaces_table_name },
        { name = "DATASOURCES_TABLE", value = var.sources_table_name },
        { name = "SOURCES_TABLE", value = var.sources_table_name },
        { name = "PROJECT_ACCESS_ROLE_ARN", value = var.smus_project_access_role_arn },
        { name = "SOURCES_API_FN_NAME", value = local.sources_api_fn_name },
        { name = "INDUCE_OUTPUT_DIR", value = "/tmp/induce" },
        { name = "PORT", value = tostring(var.container_port) },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ontology-engine"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -sf http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 5
        startPeriod = 90
      }
    },
  ])

  tags = local.tags
}

# ════════════════════════════════════════════════════════════════════
#  Fargate service (Cloud Map A-record discovery)
# ════════════════════════════════════════════════════════════════════
# cloudMapOptions equivalent: service_registries wires task IPs into the
# ontology-engine.<namespace> A records (resolvable VPC-wide, including
# from the api-proxy Lambda — unlike Service Connect).
#
# depends_on the AOSS data-access policy so the first /readiness probe does
# not race policy propagation and 403 long enough to trip the circuit
# breaker (matches CDK service.node.addDependency(ossDataAccessPolicy)).
resource "aws_ecs_service" "this" {
  name            = local.service_name
  cluster         = aws_ecs_cluster.this.arn
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.ontology_engine.arn
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  depends_on = [aws_opensearchserverless_access_policy.data]

  tags = local.tags
}
