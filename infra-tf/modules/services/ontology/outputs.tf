# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "api_fn_arn" {
  description = "API proxy Lambda ARN (forwards API Gateway → ontology-engine via Cloud Map DNS)."
  value       = aws_lambda_function.api_proxy.arn
}

output "cluster_arn" {
  description = "ECS cluster ARN hosting the ontology-engine service."
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "ECS cluster name hosting the ontology-engine service."
  value       = aws_ecs_cluster.this.name
}

output "endpoint" {
  description = "Ontology Engine internal endpoint via Cloud Map DNS (http://ontology-engine.<namespace>:<port>)."
  value       = local.endpoint
}

output "ontology_engine_table_arn" {
  description = "Ontology Engine DynamoDB table ARN."
  value       = aws_dynamodb_table.this.arn
}

output "ontology_engine_table_name" {
  description = "Ontology Engine DynamoDB table name."
  value       = aws_dynamodb_table.this.name
}

output "service_arn" {
  description = "ECS Fargate service ARN for the ontology-engine."
  value       = aws_ecs_service.this.id
}

output "service_name" {
  description = "ECS Fargate service name for the ontology-engine."
  value       = aws_ecs_service.this.name
}

output "task_definition_family" {
  description = "ECS task definition family for the ontology-engine."
  value       = aws_ecs_task_definition.this.family
}
