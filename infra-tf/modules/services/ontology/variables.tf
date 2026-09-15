# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "allowed_origin" {
  description = "CORS allowed origin for the API proxy Lambda (e.g. https://app.example.com)."
  type        = string
}

variable "aoss_security_group_id" {
  description = "AOSS VPC endpoint security group ID (from network module). The ECS task reaches AOSS over HTTPS through this endpoint."
  type        = string
}

variable "bedrock_chat_model_id" {
  description = "Bedrock chat/completion model ID (shared BedrockClient default — constraint inference, nl_generator). Injected as BEDROCK_CHAT_MODEL_ID."
  type        = string
}

variable "bedrock_embed_dimensions" {
  description = "Embedding vector dimensions for the configured Bedrock embed model. Injected as OSS_DIMENSIONS / BEDROCK_EMBED_DIMENSIONS."
  type        = number
  default     = 1024
}

variable "bedrock_embed_model_id" {
  description = "Bedrock embedding model ID (e.g. us.cohere.embed-v4:0). Injected as BEDROCK_EMBED_MODEL_ID."
  type        = string
}

variable "bedrock_induction_llm_model_id" {
  description = "Bedrock LLM model ID for ontology induction, grounding rerank, and description generation. Injected as LLM_MODEL_ID / DESCRIPTION_LLM_MODEL_ID."
  type        = string
}

variable "component" {
  description = "Component tag applied to every resource in this module."
  type        = string
  default     = "ontology"
}

variable "container_port" {
  description = "Port the ontology-engine FastAPI container listens on."
  type        = number
  default     = 8001
}

variable "cpu" {
  description = "Fargate task CPU units (1024 = 1 vCPU)."
  type        = number
  default     = 1024
}

variable "ecr_repository_url" {
  description = "ECR repository URL for the ontology-engine image (created by stack 25-ecr)."
  type        = string
}

variable "ecs_security_group_id" {
  description = "ECS Fargate task security group ID (from network module)."
  type        = string
}

variable "desired_count" {
  description = "Number of ontology-engine tasks to run."
  type        = number
  default     = 1
}

variable "image_tag_file" {
  description = "Path to artifacts/images/ontology-engine.tag (written by the image Makefile). When null, the image URI falls back to <ecr_repository_url>:latest."
  type        = string
  default     = null
}

variable "lambda_security_group_id" {
  description = "Lambda security group ID (from network module) for the API proxy Lambda's VPC config."
  type        = string
}
variable "logs_kms_key_arn" {
  description = "CMK ARN for CloudWatch Logs encryption (from modules/foundation/kms, published to <ssm_prefix>/kms/logs-key-arn). Applied to every aws_cloudwatch_log_group in this module."
  type        = string
}


variable "memory_limit_mib" {
  description = "Fargate task memory in MiB."
  type        = number
  default     = 2048
}

variable "name_prefix" {
  description = "Physical resource name prefix (<resource_prefix>-<env>)."
  type        = string
}

variable "namespaces_table_name" {
  description = "Namespaces DDB table name (from namespace module). The task role gets read access so the catalog reader can look up dataZoneProjectId per namespace."
  type        = string
}

variable "neptune_cluster_arn" {
  description = "Neptune cluster resource ARN including the trailing /* (from storage module). Used verbatim for neptune-db:* data-access grants — do NOT append another suffix."
  type        = string
}

variable "neptune_endpoint" {
  description = "Neptune cluster endpoint hostname (no scheme/port). Injected as NDB_ENDPOINT (https://<endpoint>:8182)."
  type        = string
}

variable "ontology_api_zip_path" {
  description = "Path to the built API proxy Lambda zip (produced by lambdas/ontology-api/Makefile)."
  type        = string
}

variable "ontology_bucket_arn" {
  description = "Ontology artifacts S3 bucket ARN (from storage module). Task role gets read+write for Turtle/R2RML artifacts of accepted proposals."
  type        = string
}

variable "ontology_bucket_name" {
  description = "Ontology artifacts S3 bucket name (from storage module). Injected as ONTOLOGY_ARTIFACTS_BUCKET."
  type        = string
}

variable "opensearch_collection_arn" {
  description = "AOSS collection ARN (from storage module). Scopes the aoss:APIAccessAll grant."
  type        = string
}

variable "opensearch_collection_name" {
  description = "AOSS collection name (from storage module). Injected as OSS_INDEX and used to scope the AOSS data-access policy."
  type        = string
}

variable "opensearch_endpoint" {
  description = "AOSS collection endpoint (from storage module). Injected as OSS_ENDPOINT."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (from network module) for the ECS service and API proxy Lambda."
  type        = list(string)
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "service_namespace_id" {
  description = "Cloud Map private DNS namespace ID (from network module). The ontology-engine service registers a discovery service under it."
  type        = string
}

variable "service_namespace_name" {
  description = "Cloud Map private DNS namespace name (e.g. coa-dev-services.local). Used to build the ontology-engine FQDN endpoint."
  type        = string
}

variable "smus_domain_id" {
  description = "DataZone (SMUS) domain ID (from namespace module). Required — scopes the task role's DataZone grants to a single domain; CDK fails at synth without it."
  type        = string

  validation {
    condition     = length(var.smus_domain_id) > 0
    error_message = "smus_domain_id is required — DataZone permissions cannot be granted without a domain scope."
  }
}

variable "smus_project_access_role_arn" {
  description = "DataZone project-access role ARN (from namespace module). The task role assumes it before DataZone Search/GetAsset (project membership gates reads, not IAM alone)."
  type        = string
}

variable "sources_table_name" {
  description = "Unified sources DDB table name (from sources module). Task role gets read access so the catalog reader can verify a sourceId is registered. Injected as SOURCES_TABLE / DATASOURCES_TABLE."
  type        = string
}

variable "ssm_prefix" {
  description = "SSM parameter root (e.g. /coa)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (from network module) for the API proxy Lambda placement."
  type        = string
}
