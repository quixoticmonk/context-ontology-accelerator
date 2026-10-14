# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "allowed_origin" {
  description = "Browser origin allowed to PUT/GET directly to the ontology-artifacts bucket via presigned URLs. Defaults to * in non-prod; without a matching CORS rule the browser blocks the presigned PUT."
  type        = string
  default     = "*"
}

variable "aoss_max_ocu" {
  description = "Maximum OCUs for both indexing and search on the NEXTGEN collection group. Caps cost; mirrors CDK context `aoss_max_ocu`. Must be 2, 4, 8, 16, or a multiple of 16, up to 1696."
  type        = number
  default     = 96

  validation {
    # NEXTGEN valid OCU values are 0, 2, 4, 8, 16, or multiples of 16, capped at
    # 1696 (per AWS collection-group capacity limits). max additionally cannot
    # be 0 (it is a ceiling). Validating here avoids an opaque CloudFormation
    # error after a slow stack update (upstream #173).
    condition     = contains([2, 4, 8, 16], var.aoss_max_ocu) || (var.aoss_max_ocu > 16 && var.aoss_max_ocu <= 1696 && var.aoss_max_ocu % 16 == 0)
    error_message = "aoss_max_ocu must be 2, 4, 8, 16, or a multiple of 16, up to 1696."
  }
}

variable "aoss_min_ocu" {
  description = "Minimum OCUs for both indexing and search on the NEXTGEN collection group. Set to 0 for NEXTGEN scale-to-zero. Valid NEXTGEN values: 0, 2, 4, 8, 16, or multiples of 16, up to 1696. Mirrors CDK context `aoss_min_ocu`. CAUTION with 0: indexing capacity can scale to zero, so under load the NEXTGEN circuit breaker sheds bulk writes with HTTP 429. Ingest re-submits and fails LOUD on unrecoverable partial writes (upstream #173), but 0 makes throttling far more likely. Use a non-zero floor (e.g. 2) for ingest-heavy environments."
  type        = number
  default     = 2

  validation {
    condition     = contains([0, 2, 4, 8, 16], var.aoss_min_ocu) || (var.aoss_min_ocu > 16 && var.aoss_min_ocu <= 1696 && var.aoss_min_ocu % 16 == 0)
    error_message = "aoss_min_ocu must be 0, 2, 4, 8, 16, or a multiple of 16, up to 1696."
  }
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

variable "neptune_instance_class" {
  description = "Instance class for the Neptune primary writer. Default db.r8g.large matches upstream CDK; override via `-var 'neptune_instance_class=db.r8g.xlarge'` for dev-benchmark environments where SPARQL under concurrent reasoning/metric load has OOM'd (MemoryLimitExceededException). NG.9 — never silently downgrade; only raise."
  type        = string
  default     = "db.r8g.large"
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
