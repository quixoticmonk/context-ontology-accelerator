# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "allowed_origin" {
  description = "CORS allowed origin for the four API Lambdas."
  type        = string
  default     = "*"
}

variable "cache_invalidation_table_name" {
  description = "Cache invalidation DDB table name (from authnz module). Passed through to API Lambdas for streams-based cache busting."
  type        = string
  default     = null
}

variable "cloud_map_namespace_id" {
  description = "Cloud Map private DNS namespace ID (from network module). Used by the deletion pipeline's DeletePlatform step to deregister per-namespace VKG services on teardown. Null skips the servicediscovery grants."
  type        = string
  default     = null
}

variable "component" {
  description = "Component tag applied to every resource in this module."
  type        = string
  default     = "namespace"
}

variable "control_plane_zip_path" {
  description = "Absolute path to the built control-plane Lambda zip. Produced by modules/services/namespace/lambdas/control-plane/Makefile; every Lambda in this module reads from this zip."
  type        = string
}

variable "lambda_security_group_id" {
  description = "Lambda security group ID (from network module)."
  type        = string
}

variable "name_prefix" {
  description = "Physical resource name prefix (<resource_prefix>-<env>)."
  type        = string
}

variable "ontology_bucket_name" {
  description = "Ontology artifacts S3 bucket name (from storage module). Deletion pipeline sweeps this bucket per-namespace on teardown. Null skips the S3 sweep."
  type        = string
  default     = null
}

variable "ontology_engine_endpoint" {
  description = "Ontology-engine HTTP endpoint (Cloud Map DNS, e.g. http://ontology-engine.<prefix>-services.local:8001). Used by namespace_api (preflight checks for active induction jobs) and the deletion pipeline's DeleteOntology step. Null disables both."
  type        = string
  default     = null
}

variable "opensearch_collection_name" {
  description = "AOSS collection name (from storage module). Deletion pipeline drops the namespace's GraphRAG doc-KG indexes on teardown when set."
  type        = string
  default     = null
}

variable "opensearch_endpoint" {
  description = "AOSS collection endpoint (from storage module). Deletion pipeline requires it to drop GraphRAG indexes on teardown."
  type        = string
  default     = null
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (from network module) for Lambda VPC config."
  type        = list(string)
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "resource_prefix" {
  description = "Bare resource prefix (e.g. `coa`) without the env suffix. Used for the resource-tag key that binds JDBC credential secrets to authorized namespaces (see namespaceTagKey in the CDK)."
  type        = string
}

variable "resource_role_mappings_table_arn" {
  description = "Resource role mappings DDB table ARN (from authnz module)."
  type        = string
}

variable "resource_role_mappings_table_name" {
  description = "Resource role mappings DDB table name (from authnz module)."
  type        = string
}

variable "roles_table_arn" {
  description = "Roles DDB table ARN (from authnz module)."
  type        = string
}

variable "roles_table_name" {
  description = "Roles DDB table name (from authnz module)."
  type        = string
}

variable "smus_admin_principal_arns" {
  description = "IAM role/user ARNs allowed to assume the SMUS admin login role. Empty list falls back to `arn:aws:iam::<account>:role/Admin`."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for arn in var.smus_admin_principal_arns :
      can(regex("^arn:aws[a-z-]*:iam::\\d{12}:(role|user)/[\\w+=,.@/-]+$", arn))
    ])
    error_message = "Every smus_admin_principal_arns entry must be a well-formed IAM role or user ARN."
  }
}

variable "smus_require_mfa" {
  description = "When true, deny assume-role on the SMUS login role unless MFA is present in the session."
  type        = bool
  default     = false
}

variable "ssm_prefix" {
  description = "SSM parameter root (e.g. /coa)."
  type        = string
}

variable "vkg_cluster_arn" {
  description = "VKG ECS cluster ARN (from vkg module). Used by namespace_api for read-time VKG health resolution and by the deletion pipeline for per-namespace service teardown. Null disables both."
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "VPC ID (from network module) for Lambda placement."
  type        = string
}
