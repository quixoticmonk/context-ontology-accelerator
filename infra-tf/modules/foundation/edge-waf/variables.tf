# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "component" {
  description = "Component tag applied to every resource in this module."
  type        = string
  default     = "foundation"
}

variable "name_prefix" {
  description = "Physical resource name prefix (<resource_prefix>-<env>)."
  type        = string
}

variable "ssm_prefix" {
  description = "SSM parameter root (e.g. /coa). The CloudFront WebACL ARN is published under this path for cross-region consumption by the web distribution."
  type        = string
}

variable "waf_rate_limit_per_5min" {
  description = "Max requests per rolling 5-minute window from a single source IP before that IP is blocked (rate-based rule, IP aggregate). Set to 0 to disable the rate-limit rule."
  type        = number
  default     = 2000
}
