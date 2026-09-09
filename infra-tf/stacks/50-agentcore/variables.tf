# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "allowed_override_models" {
  type    = list(string)
  default = []
}

# AgentCore-supported AZs are resolved dynamically by stack 00-network
# (which queries EC2 for the current account's zone-id → name mapping,
# intersects with AgentCore's supported physical zones, and intersects
# again with AOSS endpoint AZs) and published to
# /coa/network/agentcore-supported-az-names. Stack 50 reads them from
# SSM — no per-account tuning needed here.

variable "bedrock_embed_model_id" {
  type    = string
  default = "us.cohere.embed-v4:0"
}

variable "bedrock_llm_model_id" {
  type    = string
  default = "us.anthropic.claude-sonnet-5"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "event_source_prefix" {
  type    = string
  default = ""
}

variable "graph_base_uri" {
  type    = string
  default = "http://coa.amazon.com"
}

variable "idp_type" {
  type    = string
  default = "COGNITO"
}

variable "oidc_settings" {
  type = object({
    issuer_url  = string
    client_id   = string
    jwks_uri    = optional(string)
    group_claim = optional(string, "groups")
  })
  default = null
}

variable "project_tag" {
  type    = string
  default = "semantic-context"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "resource_prefix" {
  type    = string
  default = "coa"
}
