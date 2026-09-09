# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "api_certificate_arn" {
  type    = string
  default = null
}

variable "api_domain_name" {
  type    = string
  default = null
}

variable "bedrock_chat_model_id" {
  type    = string
  default = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "bedrock_embed_dimensions" {
  type    = number
  default = 1024
}

variable "bedrock_embed_model_id" {
  type    = string
  default = "us.cohere.embed-v4:0"
}

variable "bedrock_induction_llm_model_id" {
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

variable "hosted_zone_id" {
  type    = string
  default = null
}

variable "lambda_reserved_concurrency" {
  type    = number
  default = 5
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

variable "ui_certificate_arn" {
  type    = string
  default = null
}

variable "ui_domain_name" {
  type    = string
  default = null
}

