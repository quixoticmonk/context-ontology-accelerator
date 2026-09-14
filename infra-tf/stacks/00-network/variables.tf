# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# ── Environment identity ─────────────────────────────────────────────

variable "env" {
  type    = string
  default = "dev"
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

# ── VPC identity: create vs. bring your own ─────────────────────────

variable "azs" {
  description = "Availability zones for module-created subnets. Ignored (empty allowed) when vpc_name is set — the AZ set is read from the imported private subnets."
  type        = list(string)
  default     = ["us-east-1b", "us-east-1c"]
}

variable "vpc_name" {
  description = "Name tag of the existing VPC to import instead of creating one. When set, the network module resolves the VPC by tag:Name = vpc_name and reads private subnets from that VPC whose tag:Name matches private_subnet_name_pattern."
  type        = string
  default     = null
}

variable "private_subnet_name_pattern" {
  description = "Wildcard pattern matched against subnet tag:Name to select private subnets in the imported VPC. Ignored when vpc_name is null."
  type        = string
  default     = "*private*"
}

# ── Networking feature flags ────────────────────────────────────────
# Each flag defaults to `null`, and the network module resolves that
# to `local.create_vpc` — so BYOVPC deployments get none of these
# provisioned by default (customers manage IGW/NAT/route-tables/VPCEs/
# JDBC connectivity in their own VPC), while create-VPC deployments
# get all of them provisioned as before. Override any individual flag
# to have this module manage that primitive inside an imported VPC.

variable "create_igw" {
  type    = bool
  default = null
}

variable "create_jdbc_connectivity" {
  type    = bool
  default = null
}

variable "create_nat_gateway" {
  type    = bool
  default = null
}

variable "create_route_tables" {
  type    = bool
  default = null
}

variable "create_service_discovery_namespace" {
  description = "Provision the Cloud Map private DNS namespace. Defaults to true — the platform requires in-VPC service DNS regardless of who owns the VPC. Set to false to consume an externally-managed namespace via SSM."
  type        = bool
  default     = true
}

variable "create_vpc_endpoints" {
  type    = bool
  default = null
}

# ── JDBC cross-network connectivity inputs ─────────────────────────

variable "jdbc_peer_cidrs" {
  type    = list(string)
  default = []
}

variable "jdbc_peer_owner_id" {
  type    = string
  default = null
}

variable "jdbc_peer_region" {
  type    = string
  default = null
}

variable "jdbc_peer_vpc_id" {
  type    = string
  default = null
}

variable "jdbc_privatelink_port" {
  type    = number
  default = null
}

variable "jdbc_privatelink_private_dns" {
  type    = bool
  default = false
}

variable "jdbc_privatelink_service" {
  type    = string
  default = null
}

variable "jdbc_tgw_cidrs" {
  type    = list(string)
  default = []
}

variable "jdbc_tgw_id" {
  type    = string
  default = null
}
