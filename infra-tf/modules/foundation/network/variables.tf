# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "azs" {
  description = "Availability zone names to place subnets in when this module creates the VPC. Length must be >= 2 in that path. Ignored (and may be empty) when vpc_name is set — the AZ set is derived from the imported private subnets."
  type        = list(string)
  default     = []

  validation {
    condition     = var.vpc_name != null || length(var.azs) >= 2
    error_message = "azs must contain at least 2 availability zones when creating a VPC (vpc_name is null)."
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

variable "create_igw" {
  description = "Provision the internet gateway. Defaults to true when this module creates the VPC and false when it imports one (customers are expected to own IGW in their own VPC)."
  type        = bool
  default     = null
}

variable "create_jdbc_connectivity" {
  description = "Provision VPC peering, Transit Gateway attachment, and PrivateLink resources when their inputs are set. Defaults to true when this module creates the VPC and false when it imports one (cross-VPC routing in a customer VPC is theirs to own)."
  type        = bool
  default     = null
}

variable "create_nat_gateway" {
  description = "Provision NAT gateway + EIP. Defaults to true when this module creates the VPC and false when it imports one. Requires create_igw."
  type        = bool
  default     = null
}

variable "create_route_tables" {
  description = "Provision public + per-AZ private route tables and subnet associations. Defaults to true when this module creates the VPC and false when it imports one — customers own route tables in their own VPC."
  type        = bool
  default     = null
}

variable "create_service_discovery_namespace" {
  description = "Provision the Cloud Map private DNS namespace ({prefix}-services.local). Required for in-VPC service-to-service DNS (ontology-engine, VKG per-namespace instances). Defaults to true — most BYOVPC deployments still want a namespace inside their VPC. Set to false to consume an externally-managed namespace via SSM."
  type        = bool
  default     = true
}

variable "create_vpc_endpoints" {
  description = "Provision the S3/DDB gateway endpoint and the AWS-service interface VPC endpoints listed in locals.tf. Defaults to true when this module creates the VPC and false when it imports one. Interface endpoints are attached to the effective private subnets in either case; gateway endpoints require create_route_tables=true because they attach to private route tables."
  type        = bool
  default     = null
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

variable "private_subnet_name_pattern" {
  description = "Wildcard pattern matched against subnet tag:Name to select private subnets in the imported VPC. Ignored when vpc_name is null. Default '*private*' picks up common naming conventions; override for VPCs whose subnets are tagged differently."
  type        = string
  default     = "*private*"
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
  description = "CIDR block for the created VPC. Ignored when vpc_name is set."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "vpc_name" {
  description = "Name tag of the existing VPC to import. When set, the module looks the VPC up via data.aws_vpc filtered on tag:Name = vpc_name (exactly one VPC must match), and reads private subnets from that VPC whose tag:Name matches private_subnet_name_pattern (at least two must match). Networking primitives (IGW, NAT, route tables, VPC endpoints, JDBC connectivity) default to off in this path — customers are expected to manage them in their own VPC. Override per-primitive via the create_* flags."
  type        = string
  default     = null
}
