# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "component" {
  description = "Component tag applied to every resource in this module."
  type        = string
  default     = "kms"
}

variable "name_prefix" {
  description = "Physical resource name prefix (<resource_prefix>-<env>)."
  type        = string
}

variable "region" {
  description = "AWS region. Used to scope the CloudWatch Logs service-principal grant in the key policy to logs.<region>.amazonaws.com."
  type        = string
}

variable "ssm_prefix" {
  description = "SSM parameter root (e.g. /coa). The log-encryption key ARN is written under <ssm_prefix>/kms/logs-key-arn for downstream stacks to consume."
  type        = string
}
