# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "agentcore_az_names" {
  description = "AgentCore-supported AZ names used to filter private_subnet_ids down to subnets AgentCore Runtime can place ENIs in. When null, all private_subnet_ids are used unfiltered."
  type        = list(string)
  default     = null
}

variable "brand_env" {
  description = "Brand-specific environment variables (GRAPH_BASE_URI, EVENT_SOURCE_PREFIX) from the root config, merged into the runtime environment_variables map."
  type        = map(string)
  default     = {}
}

variable "cm_runtime_arn" {
  description = "Context Manager AgentCore Runtime ARN (from the serve module). Execution tools forward to it via the AgentCore invocations API; injected as CM_RUNTIME_ARN."
  type        = string
}

variable "component" {
  description = "Component tag applied to every resource in this module."
  type        = string
  default     = "mcp"
}

variable "ecr_repository_arn" {
  description = "ECR repository ARN for the MCP server image (from stack 25-ecr). Used to scope the runtime role's image-pull grant."
  type        = string
}

variable "ecr_repository_url" {
  description = "ECR repository URL for the MCP server image (from stack 25-ecr)."
  type        = string
}

variable "env" {
  description = "Deployment environment name (e.g. dev). Injected as ENVIRONMENT."
  type        = string
  default     = "dev"
}

variable "group_claim_name" {
  description = "JWT claim carrying group membership (cognito:groups for Cognito, or the customer's configured OIDC claim). Injected as GROUP_CLAIM_NAME for group-based role resolution."
  type        = string
  default     = "cognito:groups"
}

variable "image_tag_file" {
  description = "Path to artifacts/images/mcp-server.tag (written by the image Makefile) containing the pushed ECR image URI. When null, the image URI falls back to <ecr_repository_url>:latest."
  type        = string
  default     = null
}

variable "issuer_url" {
  description = "OIDC issuer URL (Cognito or external IdP). The JWT authorizer discovery URL is built as <issuer_url>/.well-known/openid-configuration; also injected as JWT_ISSUER_URL."
  type        = string
}

variable "mcp_client_id" {
  description = "MCP CLI OAuth client ID (from auth-idp). Second entry in the JWT authorizer allowed_audience and injected as JWT_CLIENT_ID (MCP callers authenticate as the CLI client)."
  type        = string
}

variable "metric_service_lambda_arn" {
  description = "Metric Service API Lambda ARN (from the metric_service module). Granted lambda:InvokeFunction for the discovery tools and injected as METRIC_SERVICE_LAMBDA_ARN."
  type        = string
}

variable "name_prefix" {
  description = "Physical resource name prefix (<resource_prefix>-<env>)."
  type        = string
}

variable "ontology_proxy_lambda_arn" {
  description = "Ontology Engine API proxy Lambda ARN (from the ontology module). Granted lambda:InvokeFunction for the discovery tools and injected as ONTOLOGY_PROXY_LAMBDA_ARN."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (from the network module) for AgentCore Runtime ENIs. Filtered by agentcore_az_names when that variable is set."
  type        = list(string)
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "resource_role_mappings_table_arn" {
  description = "Resource-role-mappings DDB table ARN (from the authnz module). The runtime role gets read access (plus its index/*) for the MCP grant resolver."
  type        = string
}

variable "resource_role_mappings_table_name" {
  description = "Resource-role-mappings DDB table name (from the authnz module). Injected as RRM_TABLE_NAME."
  type        = string
}

variable "roles_table_arn" {
  description = "Roles DDB table ARN (from the authnz module). The runtime role gets read access for the MCP grant resolver."
  type        = string
}

variable "roles_table_name" {
  description = "Roles DDB table name (from the authnz module). Injected as ROLES_TABLE_NAME."
  type        = string
}

variable "ssm_prefix" {
  description = "SSM parameter root (e.g. /coa). Used for SSM parameter writes and to scope the runtime role's ssm:GetParameter grant."
  type        = string
}

variable "userpool_client_id" {
  description = "Web app OAuth client ID (from auth-idp). First entry in the JWT authorizer allowed_audience."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block. Scopes the HTTPS egress rule to VPC endpoints (AgentCore)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (from the network module) for the AgentCore Runtime security group."
  type        = string
}
