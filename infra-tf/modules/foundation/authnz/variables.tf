# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "cedar_seed_path" {
  description = "Filesystem path to the directory containing Cedar policy files for built-in roles (default.cedar, global_admin.cedar, ...). When null, built-in role seeding is skipped. In-repo default: <repo>/libs/common/src/coa_authorization/seed."
  type        = string
  default     = null
}

variable "claims_mappings" {
  description = "IdP group to role claim mappings seeded into the resource-role-mappings table. Each entry grants every role in mapped_roles to the named group at platform-global scope, mirroring the CDK SeedGroupMapping custom resources."
  type = list(object({
    group_value  = string
    mapped_roles = list(string)
  }))
  default = []
}

variable "component" {
  description = "Component tag applied to every resource in this module."
  type        = string
  default     = "foundation"
}

variable "environment" {
  description = "Deployment environment name. When set to prod, DynamoDB deletion protection is enabled on all tables (mirrors the CDK RETAIN removal policy in prod)."
  type        = string
  default     = "dev"
}

variable "name_prefix" {
  description = "Physical resource name prefix (<resource_prefix>-<env>). DynamoDB tables are named <name_prefix>-<logical-table-name>."
  type        = string
}

variable "ssm_prefix" {
  description = "SSM parameter root (e.g. /coa). Runtime services read AuthNZ table metadata under this path."
  type        = string
}
