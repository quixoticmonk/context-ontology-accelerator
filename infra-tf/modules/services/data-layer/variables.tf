# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "allowed_origin" {
  description = "CORS allowed origin for the data-layer API Lambda."
  type        = string
  default     = "*"
}

variable "component" {
  description = "Component tag applied to every resource in this module."
  type        = string
  default     = "data-layer"
}

variable "data_layer_zip_path" {
  description = "Absolute path to the built data-layer Lambda zip. Produced by modules/services/data-layer/lambdas/data-layer/Makefile."
  type        = string
}

variable "lambda_security_group_id" {
  description = "Lambda security group ID (from network module)."
  type        = string
}

variable "name_prefix" {
  description = "Physical resource name prefix (resource_prefix-env)."
  type        = string
}

variable "namespaces_table_name" {
  description = "Namespaces DDB table name (from namespace module)."
  type        = string
}

variable "ontology_engine_api_fn_arn" {
  description = "Ontology-engine api-proxy Lambda ARN (from ontology module). Data-layer proxies schema queries straight through to it, bypassing the Context Manager. Null skips both the env var and the invoke grant."
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

variable "serve_runtime_arn" {
  description = "AgentCore Runtime ARN (from serve module). Data-layer invokes it via bedrock-agentcore InvokeAgentRuntime for query/translate/kb/graph requests. Null skips both the env var and the invoke grant."
  type        = string
  default     = null
}

variable "ssm_prefix" {
  description = "SSM parameter root (e.g. /coa)."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (from network module) for Lambda placement."
  type        = string
}
