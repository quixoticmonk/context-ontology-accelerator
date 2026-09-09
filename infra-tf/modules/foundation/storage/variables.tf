# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "allowed_origin" {
  description = "Browser origin allowed to PUT/GET directly to the ontology-artifacts bucket via presigned URLs. Defaults to * in non-prod; without a matching CORS rule the browser blocks the presigned PUT."
  type        = string
  default     = "*"
}

variable "aoss_max_ocu" {
  description = "Maximum OCUs for both indexing and search on the NEXTGEN collection group. Caps cost; mirrors CDK context `aoss_max_ocu`."
  type        = number
  default     = 96
}

variable "aoss_min_ocu" {
  description = "Minimum OCUs for both indexing and search on the NEXTGEN collection group. Set to 0 for NEXTGEN scale-to-zero. Valid NEXTGEN values: 0, 2, 4, 8, 16, or multiples of 16. Mirrors CDK context `aoss_min_ocu`."
  type        = number
  default     = 2
}

variable "aoss_security_group_id" {
  description = "Security group attached to the AOSS VPC endpoint (from the network module). Referenced so the storage module orders after network connectivity is in place."
  type        = string
}

variable "aoss_vpc_endpoint_id" {
  description = "AOSS data-plane VPC endpoint ID (from the network module). Referenced by the AOSS network security policy to scope collection + dashboard access to VPC-internal traffic. In `dev` an additional AllowFromPublic rule is added; every other env is VPCE-only."
  type        = string
}

variable "component" {
  description = "Component tag applied to every resource in this module."
  type        = string
  default     = "foundation"
}

variable "env" {
  description = "Deployment environment name. Gates prod retain-vs-destroy behavior on Neptune and S3 buckets."
  type        = string
}

variable "name_prefix" {
  description = "Physical resource name prefix (<resource_prefix>-<env>)."
  type        = string
}

variable "neptune_security_group_id" {
  description = "Security group attached to the Neptune cluster (from the network module)."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (from the network module) for the Neptune DB subnet group."
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "private_subnet_ids must contain at least 2 subnets across distinct AZs for Neptune."
  }
}

variable "region" {
  description = "AWS region — used to construct the Neptune data-access ARN."
  type        = string
}

variable "ssm_prefix" {
  description = "SSM parameter root (e.g. /coa). Runtime services read storage config under this path."
  type        = string
}
