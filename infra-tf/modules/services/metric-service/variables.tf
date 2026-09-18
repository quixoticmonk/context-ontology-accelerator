# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "allowed_origin" {
  description = "CORS allowed origin for the metric API Lambda and OSI staging bucket."
  type        = string
  default     = "*"
}

variable "aoss_security_group_id" {
  description = "AOSS VPC endpoint security group ID (from network module). This module adds an ingress rule allowing the Lambda security group to reach the endpoint on 443."
  type        = string
}

variable "bedrock_embed_model_id" {
  description = "Bedrock embedding model ID for metric matching. Defaults to the us.cohere.embed-v4:0 cross-region inference profile."
  type        = string
  default     = "us.cohere.embed-v4:0"
}

variable "brand_env" {
  description = "Brand-specific env map (GRAPH_BASE_URI + EVENT_SOURCE_PREFIX). GRAPH_BASE_URI feeds NDB_GRAPH_URI_BASE on both Lambdas so metric writes land on the same named-graph base URI that serve reads from — the CDK DEFAULT_GRAPH_URI_BASE consolidation. EVENT_SOURCE_PREFIX is accepted for symmetry with peer modules; metric-service does not currently emit EventBridge events."
  type        = map(string)
}

variable "component" {
  description = "Component tag applied to every resource in this module."
  type        = string
  default     = "metric-service"
}

variable "event_bus_name" {
  description = "EventBridge bus name for metric lifecycle events."
  type        = string
  default     = "default"
}

variable "lambda_security_group_id" {
  description = "Lambda security group ID (from network module) for the API and import worker functions."
  type        = string
}

variable "metric_service_zip_path" {
  description = "Absolute path to the built metric-service Lambda zip. Produced by modules/services/metric-service/lambdas/metric-service/Makefile; both Lambdas read from this zip."
  type        = string
}

variable "name_prefix" {
  description = "Physical resource name prefix (<resource_prefix>-<env>)."
  type        = string
}

variable "namespaces_table_name" {
  description = "Namespaces DDB table name (from namespace module). Read by both Lambdas for SMUS catalog validation."
  type        = string
}

variable "neptune_cluster_arn" {
  description = "Neptune cluster ARN for IAM scoping (from storage module). Uses cluster_resource_id form with a /* suffix for neptune-db data-access actions."
  type        = string
}

variable "neptune_endpoint" {
  description = "Neptune cluster writer endpoint host (from storage module), without protocol or port."
  type        = string
}

variable "opensearch_collection_arn" {
  description = "AOSS collection ARN (from storage module) for the aoss:APIAccessAll IAM grant."
  type        = string
}

variable "opensearch_collection_name" {
  description = "AOSS collection name (from storage module). Used as the OSS index prefix env var and to scope the AOSS data-access policy."
  type        = string
}

variable "opensearch_endpoint" {
  description = "AOSS collection endpoint (from storage module). Injected as OPENSEARCH_ENDPOINT into both Lambdas."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (from network module) for Lambda VPC config."
  type        = list(string)
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "smus_domain_id" {
  description = "SMUS (DataZone) domain ID (from namespace module). Injected as SMUS_DOMAIN_ID for catalog validation. Null omits the env var."
  type        = string
  default     = null
}

variable "smus_project_access_role_arn" {
  description = "Shared DataZone project access role ARN (from namespace module). Both Lambdas assume it (sts:AssumeRole) for SMUS catalog operations. Null omits the grant and env var."
  type        = string
  default     = null
}

variable "sources_table_name" {
  description = "Sources DDB table name (from sources module). Read by both Lambdas for SMUS catalog validation. Sources deploys after metric-service in dependency order, so this is taken as a plain string and resolved at plan time."
  type        = string
}

variable "ssm_prefix" {
  description = "SSM parameter root (e.g. /coa)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (from network module) for Lambda placement."
  type        = string
}
