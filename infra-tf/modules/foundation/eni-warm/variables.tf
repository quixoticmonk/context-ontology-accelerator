# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "name_prefix" {
  description = "Resource name prefix (e.g. `coa-dev`). Function names become `<name_prefix>-eni-warm-<combo>`."
  type        = string
}

variable "component" {
  description = "Component tag applied to every resource. Defaults to `foundation`."
  type        = string
  default     = "foundation"
}

variable "private_subnet_ids" {
  description = "Private-with-egress subnet IDs. Lambda creates one Hyperplane ENI per (subnet, SG-set) combination, so the ENI count is `len(subnets) * len(combos)`."
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Shared Lambda SG. Pre-warms the combination used by every normal VPC Lambda (namespace API, metric API, control-plane, etc.)."
  type        = string
}

variable "discovery_ocsp_security_group_id" {
  description = "Snowflake OCSP SG. Combined with the shared Lambda SG, pre-warms the combination `sources-db-connector` uses for port-80 OCSP + port-443 HTTPS egress."
  type        = string
}

variable "ecs_security_group_id" {
  description = "ECS task SG. Pre-warms the combination the vkg reload Lambda uses (runs on the ECS SG for Cloud Map DNS)."
  type        = string
}

variable "authorizer_security_group_id" {
  description = "API authorizer SG. Pre-warms the dedicated authorizer combination so the authorizer Lambda does not pay the Hyperplane ENI create cost on its first deploy."
  type        = string
}

variable "logs_kms_key_arn" {
  description = "CMK ARN for CloudWatch Logs encryption, applied to each eni-warm function's log group."
  type        = string
}

variable "tags" {
  description = "Tags applied to each eni-warm Lambda, log group, and the shared exec role."
  type        = map(string)
  default     = {}
}
