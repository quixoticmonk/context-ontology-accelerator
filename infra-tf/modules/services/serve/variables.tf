# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "agentcore_az_names" {
  description = "Defensive filter for AgentCore-supported AZs. When set, only subnets whose AZ is in this list are handed to the Runtime."
  type        = list(string)
  default     = null
}

variable "allowed_override_models" {
  description = "Bedrock model IDs allowed for per-request override via options.modelId. Empty means any valid model ID is accepted."
  type        = list(string)
  default     = []
}

variable "aoss_proxy_zip_path" {
  description = "Path to the built AOSS search proxy Lambda zip."
  type        = string
}

variable "aoss_security_group_id" {
  description = "AOSS VPC endpoint security group ID (from network). The AgentCore SG needs an ingress rule allowing HTTPS from the AgentCore SG here."
  type        = string
}

variable "aoss_vpc_endpoint_id" {
  description = "AOSS data-plane VPC endpoint ID (from network)."
  type        = string
}

variable "athena_results_bucket_name" {
  description = "Athena query results bucket (from storage). Runtime writes results here."
  type        = string
}

variable "athena_spill_bucket_name" {
  description = "Athena federation spill bucket (from storage). Runtime reads spilled connector results here."
  type        = string
}

variable "bedrock_embed_model_id" {
  description = "Bedrock embedding model ID (must match what doc-kg-build ingested with)."
  type        = string
  default     = "us.cohere.embed-v4:0"
}

variable "bedrock_llm_model_id" {
  description = "Bedrock LLM model ID for query resolution."
  type        = string
  default     = "us.anthropic.claude-sonnet-5"
}

variable "brand_env" {
  description = "GRAPH_BASE_URI + EVENT_SOURCE_PREFIX to inject into the runtime environment."
  type        = map(string)
  default     = {}
}

variable "component" {
  description = "Component tag."
  type        = string
  default     = "serve"
}

variable "ecr_repository_arn" {
  description = "ECR repository ARN for the Context Manager image (from stack 25-ecr). Used to scope the runtime role's image-pull grant."
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL for the Context Manager image (from stack 25-ecr)."
  type        = string
}

variable "connector_spill_key_glob" {
  description = "Key prefix under which every federated connector spills. Used as the resource pattern in the AthenaFederationSpillRead statement AND as the s3:prefix in ListBucket. `connectors/*/spills/*`."
  type        = string
  default     = "connectors/*/spills/*"
}

variable "connector_spill_kms_tag_key" {
  description = "KMS key tag key (e.g. `coa:connector-spill`) required on a connector's spill-bucket SSE-KMS key. Scopes the kms:Decrypt grant."
  type        = string
}

variable "connector_spill_kms_tag_value" {
  description = "KMS key tag value (e.g. `true`)."
  type        = string
  default     = "true"
}

variable "connector_tag_key" {
  description = "Lambda tag key (e.g. `coa:connector`) required on a federated connector Lambda. Scopes the AthenaFederationConnectorInvoke Allow AND the same-tag DenyAthenaInvokeOfUntaggedFunctions."
  type        = string
}

variable "connector_tag_value" {
  description = "Lambda tag value (e.g. `true`)."
  type        = string
  default     = "true"
}

variable "env" {
  description = "Deployment environment name."
  type        = string
  default     = "dev"
}

variable "image_tag_file" {
  description = "Path to artifacts/images/context-manager.tag containing the pushed ECR image URI. Null falls back to `<ecr_repo>:latest`."
  type        = string
  default     = null
}

variable "issuer_url" {
  description = "OIDC issuer URL. Used to build the JWT authorizer discovery URL."
  type        = string
}

variable "lambda_security_group_id" {
  description = "Lambda security group ID for the AOSS proxy Lambda."
  type        = string
}

variable "mcp_client_id" {
  description = "MCP OAuth client ID. Included in the JWT authorizer's allowed_audience."
  type        = string
}

variable "name_prefix" {
  description = "<resource_prefix>-<env>."
  type        = string
}

variable "namespace_tag_key" {
  description = "The `{prefix}:namespace` tag key. Used in the Null condition on the ReadPlatformSecrets statement so platform secrets (untagged) are readable by identity while namespace-bound credential secrets stay gated by their resource policies."
  type        = string
}

variable "namespaces_table_arn" {
  description = "Namespaces DDB table ARN (from namespace)."
  type        = string
}

variable "namespaces_table_name" {
  description = "Namespaces DDB table name."
  type        = string
}

variable "neptune_cluster_arn" {
  description = "Neptune cluster ARN with the trailing /*."
  type        = string
}

variable "neptune_endpoint" {
  description = "Neptune cluster endpoint."
  type        = string
}

variable "ontology_bucket_arn" {
  description = "Ontology artifacts bucket ARN."
  type        = string
}

variable "opensearch_collection_arn" {
  description = "AOSS collection ARN."
  type        = string
}

variable "opensearch_collection_name" {
  description = "AOSS collection name."
  type        = string
}

variable "opensearch_endpoint" {
  description = "AOSS collection endpoint."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs."
  type        = list(string)
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "resource_prefix" {
  description = "Bare resource prefix (e.g. `coa`) without the env suffix. Used for the sanitized federated catalog prefix + S3 bucket prefix ARN scoping."
  type        = string
}

variable "resource_role_mappings_table_arn" {
  description = "Resource role mappings DDB table ARN."
  type        = string
}

variable "resource_role_mappings_table_name" {
  description = "Resource role mappings DDB table name."
  type        = string
}

variable "roles_table_arn" {
  description = "Roles DDB table ARN."
  type        = string
}

variable "roles_table_name" {
  description = "Roles DDB table name."
  type        = string
}

variable "group_claim_name" {
  description = "JWT claim name carrying group membership."
  type        = string
  default     = "cognito:groups"
}

variable "sources_table_name" {
  description = "Sources DDB table name (from sources, by convention)."
  type        = string
}

variable "ssm_prefix" {
  description = "SSM parameter root."
  type        = string
}

variable "userpool_client_id" {
  description = "Web app OAuth client ID (Cognito user pool client). Included in the JWT authorizer's allowed_audience."
  type        = string
}

variable "vkg_endpoint" {
  description = "VKG service endpoint (Cloud Map DNS URL for the SPARQL translator)."
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "VPC CIDR for the AgentCore SG egress rule."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}
