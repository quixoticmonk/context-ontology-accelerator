# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Stack 00 — Network foundation (VPC, subnets, security groups,
# Cloud Map namespace, VPC endpoints). Downstream stacks read these
# values via SSM Parameter Store.

module "network" {
  source = "../../modules/foundation/network"

  # Resolved from AgentCore + AOSS supported zone IDs (see locals.tf).
  # var.azs is now advisory / legacy — the resolved list wins in restricted
  # regions. In unrestricted regions, fall back to the user-provided list.
  azs                          = local.restricted_zone_ids == null ? var.azs : local.resolved_azs
  connector_egress_cidrs       = []
  connector_ocsp_egress        = true
  jdbc_peer_cidrs              = var.jdbc_peer_cidrs
  jdbc_peer_owner_id           = var.jdbc_peer_owner_id
  jdbc_peer_region             = var.jdbc_peer_region
  jdbc_peer_vpc_id             = var.jdbc_peer_vpc_id
  jdbc_privatelink_port        = var.jdbc_privatelink_port
  jdbc_privatelink_private_dns = var.jdbc_privatelink_private_dns
  jdbc_privatelink_service     = var.jdbc_privatelink_service
  jdbc_tgw_cidrs               = var.jdbc_tgw_cidrs
  jdbc_tgw_id                  = var.jdbc_tgw_id
  name_prefix                  = local.name_prefix
  region                       = var.region
  ssm_prefix                   = local.ssm_prefix
  vpc_id                       = var.vpc_id
}

# ── Stack-level SSM writes for values the module does not publish ────
# The network module writes vpc_id, service_namespace_id, and
# service_namespace_name. Everything else consumed cross-stack lives
# in these resources.

resource "aws_ssm_parameter" "private_subnet_ids" {
  name  = "${local.ssm_prefix}/network/private-subnet-ids"
  type  = "StringList"
  value = join(",", module.network.private_subnet_ids)
}

resource "aws_ssm_parameter" "vpc_cidr_block" {
  name  = "${local.ssm_prefix}/network/vpc-cidr-block"
  type  = "String"
  value = module.network.vpc_cidr_block
}

resource "aws_ssm_parameter" "aoss_security_group_id" {
  name  = "${local.ssm_prefix}/network/aoss-security-group-id"
  type  = "String"
  value = module.network.aoss_security_group_id
}

resource "aws_ssm_parameter" "aoss_vpc_endpoint_id" {
  name  = "${local.ssm_prefix}/network/aoss-vpc-endpoint-id"
  type  = "String"
  value = coalesce(module.network.aoss_vpc_endpoint_id, "none")
}

resource "aws_ssm_parameter" "lambda_security_group_id" {
  name  = "${local.ssm_prefix}/network/lambda-security-group-id"
  type  = "String"
  value = module.network.lambda_security_group_id
}

resource "aws_ssm_parameter" "ecs_security_group_id" {
  name  = "${local.ssm_prefix}/network/ecs-security-group-id"
  type  = "String"
  value = module.network.ecs_security_group_id
}

resource "aws_ssm_parameter" "neptune_security_group_id" {
  name  = "${local.ssm_prefix}/network/neptune-security-group-id"
  type  = "String"
  value = module.network.neptune_security_group_id
}

resource "aws_ssm_parameter" "connector_security_group_id" {
  name  = "${local.ssm_prefix}/network/connector-security-group-id"
  type  = "String"
  value = module.network.connector_security_group_id
}

resource "aws_ssm_parameter" "service_namespace_arn" {
  name  = "${local.ssm_prefix}/network/service-namespace-arn"
  type  = "String"
  value = module.network.service_namespace_arn
}

# Resolved AgentCore-supported AZ names, published for stack 50-agentcore
# to consume without hardcoding per-account friendly names.
resource "aws_ssm_parameter" "agentcore_supported_az_names" {
  name  = "${local.ssm_prefix}/network/agentcore-supported-az-names"
  type  = "StringList"
  value = local.restricted_zone_ids == null ? join(",", data.aws_availability_zones.this.names) : join(",", local.resolved_azs)
}
