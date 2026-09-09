# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Inputs for the sources module. Alphabetized. Additional Lambda- and
# ECS-specific inputs (image URIs, zip paths, cross-service ARNs) are
# added in sub-turns 2-4 as those pieces land.

variable "allowed_origin" {
  description = "CORS allowed origin for the sources-data bucket presigned uploads."
  type        = string
  default     = "*"
}

variable "aoss_security_group_id" {
  description = "AOSS VPC endpoint security group ID (from network). Referenced by KG-build task role."
  type        = string
}

variable "athena_results_bucket_arn" {
  description = "Athena query results bucket ARN (from storage). Referenced in the preprocessing DENY policy to prevent read access to platform-owned buckets."
  type        = string
}

variable "athena_spill_bucket_arn" {
  description = "Athena federated connector spill bucket ARN (from storage)."
  type        = string
}

variable "athena_spill_bucket_name" {
  description = "Athena federated connector spill bucket name (from storage)."
  type        = string
}

variable "bedrock_chat_model_id" {
  description = "Bedrock chat/completion model ID used by the database-enrichment task. Also drives the bedrockModelArn output that scopes the task role's Bedrock IAM."
  type        = string
  default     = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "bedrock_embed_dimensions" {
  description = "Embedding vector dimensions for the doc-KG-build container's embedding model. Must equal the value the AOSS index was created with."
  type        = number
  default     = 1024
}

variable "bedrock_embed_model_id" {
  description = "Bedrock embedding model ID for doc-KG-build. MUST match what serve queries with (vectors from different models are incomparable)."
  type        = string
  default     = "us.cohere.embed-v4:0"
}

variable "component" {
  description = "Component tag applied to every resource in this module."
  type        = string
  default     = "sources"
}

variable "connector_security_group_id" {
  description = "Glue connector security group ID (from network). Applied to Glue Connections at runtime."
  type        = string
}

variable "db_enrichment_ecr_repository_url" {
  description = "ECR repository URL for the sources-db-enrichment image (from stack 25-ecr)."
  type        = string
}

variable "db_enrichment_image_tag_file" {
  description = "Path to artifacts/images/sources-db-enrichment.tag containing the pushed ECR image URI. When null, the URI falls back to `<ecr_repo>:latest`."
  type        = string
  default     = null
}

variable "kg_build_ecr_repository_url" {
  description = "ECR repository URL for the sources-doc-kg-build image (from stack 25-ecr)."
  type        = string
}

variable "lakeformation_admin_zip_path" {
  description = "Path to the built lakeformation-admin Lambda zip (produced by modules/services/sources/lambdas/lakeformation-admin/Makefile)."
  type        = string
}

variable "kg_build_image_tag_file" {
  description = "Path to artifacts/images/sources-kg-build.tag containing the pushed ECR image URI. When null, the URI falls back to `<ecr_repo>:latest`."
  type        = string
  default     = null
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrency for the preprocessing DockerImageFunction. Caps document-preprocessing fan-out. 0 omits the reservation (required on reduced-quota accounts)."
  type        = number
  default     = 5
}

variable "preprocessing_ecr_repository_url" {
  description = "ECR repository URL for the sources-doc-preprocessing image (from stack 25-ecr)."
  type        = string
}

variable "preprocessing_image_tag_file" {
  description = "Path to artifacts/images/sources-preprocessing.tag containing the pushed ECR image URI for the preprocessing DockerImageFunction. When null, falls back to `<ecr_repo>:latest`."
  type        = string
  default     = null
}

variable "db_scan_enrichment_timeout_minutes" {
  description = "Catchable per-task timeout on the enrichment ECS step in the dbScan Step Function. States.Timeout is caught → SCAN_FAILED. The state-machine timeout is this + 2 min so the catchable path always fires first."
  type        = number
  default     = 120

  validation {
    condition     = var.db_scan_enrichment_timeout_minutes > 0
    error_message = "db_scan_enrichment_timeout_minutes must be positive."
  }
}

variable "ecs_security_group_id" {
  description = "ECS Fargate task security group ID (from network)."
  type        = string
}

variable "env" {
  description = "Deployment environment name. Gates prod retain-vs-destroy on S3 buckets."
  type        = string
}

variable "lambda_security_group_id" {
  description = "Lambda function security group ID (from network)."
  type        = string
}

variable "name_prefix" {
  description = "Physical resource name prefix (<resource_prefix>-<env>)."
  type        = string
}

variable "namespace_tag_key" {
  description = "Resource-tag key that binds JDBC credential secrets to authorized namespaces (e.g. `coa:namespace`). Derived from resource_prefix; kept as an explicit input so the IAM conditions and runtime env vars cannot drift."
  type        = string
}

variable "namespaces_table_arn" {
  description = "Namespaces DDB table ARN (from namespace module). Read by discovery + enrichment for dataZoneProjectId lookups."
  type        = string
}

variable "namespaces_table_name" {
  description = "Namespaces DDB table name (from namespace module)."
  type        = string
}

variable "neptune_cluster_arn" {
  description = "Neptune cluster resource ARN including trailing /* (from storage)."
  type        = string
}

variable "neptune_endpoint" {
  description = "Neptune cluster writer endpoint (from storage)."
  type        = string
}

variable "opensearch_collection_arn" {
  description = "AOSS collection ARN (from storage)."
  type        = string
}

variable "opensearch_collection_name" {
  description = "AOSS collection name (from storage)."
  type        = string
}

variable "opensearch_endpoint" {
  description = "AOSS collection endpoint (from storage)."
  type        = string
}

variable "ontology_bucket_arn" {
  description = "Ontology artifacts S3 bucket ARN (from storage). Doc-KG-build reads compiled ontology assets from here."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (from network)."
  type        = list(string)
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "resource_prefix" {
  description = "Bare resource prefix (e.g. `coa`) without env suffix. Used to derive the sanitized federation catalog prefix and the namespace tag key."
  type        = string
}

variable "smus_domain_id" {
  description = "DataZone/SMUS domain ID (from namespace)."
  type        = string
}

variable "smus_project_access_role_arn" {
  description = "Shared DataZone project access role ARN (from namespace). Discovery and enrichment task roles assume it for DataZone catalog writes."
  type        = string
}

variable "sources_db_trigger_zip_path" {
  description = "Path to the built db-scan-trigger Lambda zip (minimal, just the trigger source). Produced by modules/services/sources/lambdas/sources-db-trigger/Makefile."
  type        = string
}

variable "sources_doc_cleanup_zip_path" {
  description = "Path to the built doc-cleanup Lambda zip. Produced by modules/services/sources/lambdas/sources-doc-cleanup/Makefile."
  type        = string
}

variable "sources_doc_trigger_zip_path" {
  description = "Path to the built doc-ingestion-trigger Lambda zip. Produced by modules/services/sources/lambdas/sources-doc-trigger/Makefile."
  type        = string
}

variable "sources_zip_path" {
  description = "Path to the built shared sources Lambda zip (superset used by dbConnector, federationProvisioner, dbScanReaper, bulkReviewWorker, sourcesApi). Produced by modules/services/sources/lambdas/sources/Makefile."
  type        = string
}

variable "ssm_prefix" {
  description = "SSM parameter root (e.g. /coa)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (from network)."
  type        = string
}
