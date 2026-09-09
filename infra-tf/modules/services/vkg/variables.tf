# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "component" {
  description = "Component tag applied to every resource in this module."
  type        = string
  default     = "vkg"
}

variable "container_port" {
  description = "Container port the Ontop SPARQL endpoint listens on."
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "Fargate CPU units for the VKG task definition (1024 = 1 vCPU)."
  type        = number
  default     = 1024
}

variable "ecr_repository_url" {
  description = "ECR repository URL for the VKG image (created by stack 25-ecr)."
  type        = string
}

variable "ecs_security_group_id" {
  description = "ECS Fargate task security group ID (from network module). Applied to per-namespace VKG services by the reload Lambda."
  type        = string
}

variable "event_source_prefix" {
  description = "EventBridge source prefix that ontology publishers emit under. The reload rule matches source <event_source_prefix>.ontology. Matches the emitter's EVENT_SOURCE_PREFIX env var."
  type        = string
  default     = "coa"
}

variable "image_tag_file" {
  description = "Path to the built image tag file (artifacts/images/vkg.tag) containing the full pushed ECR image URI. Null falls back to <ecr_repo>:latest."
  type        = string
  default     = null
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrency for the reload Lambda; bounds its blast radius since it drives serial ECS updates. 0 omits the reservation so the module deploys on reduced-quota accounts."
  type        = number
  default     = 5
}

variable "lambda_security_group_id" {
  description = "Lambda function security group ID (from network module) for the reload Lambda VPC config."
  type        = string
}

variable "memory_limit_mib" {
  description = "Fargate memory in MiB for the VKG task definition."
  type        = number
  default     = 2048
}

variable "name_prefix" {
  description = "Physical resource name prefix (<resource_prefix>-<env>)."
  type        = string
}

variable "ontology_bucket_arn" {
  description = "Ontology artifacts S3 bucket ARN (from storage module). The task role reads the compiled ontology and R2RML mappings from this bucket."
  type        = string
}

variable "ontology_bucket_name" {
  description = "Ontology artifacts S3 bucket name (from storage module). Injected into the task and reload Lambda as ONTOLOGY_BUCKET."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (from network module) for the reload Lambda VPC config and per-namespace VKG services."
  type        = list(string)
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "service_namespace_id" {
  description = "Cloud Map private DNS namespace ID (from network module). The reload Lambda registers per-namespace VKG services under it."
  type        = string
}

variable "service_namespace_name" {
  description = "Cloud Map private DNS namespace name (e.g. coa-dev-services.local). Used to build the VKG endpoint pattern."
  type        = string
}

variable "ssm_prefix" {
  description = "SSM parameter root (e.g. /coa)."
  type        = string
}

variable "vkg_reload_zip_path" {
  description = "Path to the built reload Lambda zip. Produced by modules/services/vkg/lambdas/reload/Makefile."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (from network module) for the reload Lambda placement."
  type        = string
}
