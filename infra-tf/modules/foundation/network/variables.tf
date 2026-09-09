# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "azs" {
  description = "Availability zone names to place subnets in. Length must be >= 2."
  type        = list(string)

  validation {
    condition     = length(var.azs) >= 2
    error_message = "azs must contain at least 2 availability zones."
  }
}

variable "component" {
  description = "Component tag applied to every resource in this module."
  type        = string
  default     = "foundation"
}

variable "connector_egress_cidrs" {
  description = "Remote CIDRs the connector security group is allowed to reach on source-database ports. Empty list allows egress to anywhere (matches the CDK default). Set to narrow egress to a known NAT/proxy range."
  type        = list(string)
  default     = []
}

variable "connector_ocsp_egress" {
  description = "Enable the connector security group's port-80 egress rule for OCSP certificate revocation checks. Required for the Snowflake driver to avoid a ~5-30s per-responder soft-fail latency; harmless for other engines."
  type        = bool
  default     = true
}

variable "jdbc_peer_cidrs" {
  description = "Remote CIDRs reachable via VPC peering. Empty list disables peering."
  type        = list(string)
  default     = []
}

variable "jdbc_peer_owner_id" {
  description = "AWS account ID of the peer VPC (cross-account peering). Null for same-account."
  type        = string
  default     = null
}

variable "jdbc_peer_region" {
  description = "Region of the peer VPC (cross-region peering). Null for same-region."
  type        = string
  default     = null
}

variable "jdbc_peer_vpc_id" {
  description = "Peer VPC ID for VPC peering. Null disables peering."
  type        = string
  default     = null
}

variable "jdbc_privatelink_port" {
  description = "PrivateLink endpoint port. Null disables PrivateLink."
  type        = number
  default     = null
}

variable "jdbc_privatelink_private_dns" {
  description = "Enable private DNS for the PrivateLink endpoint."
  type        = bool
  default     = false
}

variable "jdbc_privatelink_service" {
  description = "PrivateLink endpoint service name (e.g. com.amazonaws.vpce.us-east-1.vpce-svc-xxx). Null disables PrivateLink."
  type        = string
  default     = null
}

variable "jdbc_tgw_cidrs" {
  description = "Remote CIDRs reachable via Transit Gateway. Empty list disables TGW routing."
  type        = list(string)
  default     = []
}

variable "jdbc_tgw_id" {
  description = "Transit Gateway ID to attach the VPC to. Null disables TGW."
  type        = string
  default     = null
}

variable "name_prefix" {
  description = "Physical resource name prefix (<resource_prefix>-<env>)."
  type        = string
}

variable "region" {
  description = "AWS region — used to build service names for AOSS control-plane and AOSS-data VPC endpoints (no CDK constant for the AOSS suffix pair)."
  type        = string
}

variable "ssm_prefix" {
  description = "SSM parameter root (e.g. /coa). Runtime services read config under this path."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the created VPC. Ignored when vpc_id is set."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "vpc_id" {
  description = "Existing VPC ID to import instead of creating one. When set, VPC endpoints and JDBC connectivity are NOT provisioned — they must be managed externally."
  type        = string
  default     = null
}
