# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "cluster_arn" {
  description = "VKG ECS cluster ARN. Consumed by namespace_api (VKG health) and the deletion pipeline."
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "VKG ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "container_port" {
  description = "Container port the Ontop SPARQL endpoint listens on."
  value       = var.container_port
}

output "service_namespace_name" {
  description = "Cloud Map private DNS namespace name used for per-namespace VKG service discovery."
  value       = var.service_namespace_name
}

output "task_definition_family" {
  description = "VKG task-definition template family. Per-namespace revisions are registered under a derived family at runtime."
  value       = aws_ecs_task_definition.this.family
}
