# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  # ── VPC creation vs. import ────────────────────────────────────────
  create_vpc = var.vpc_id == null
  vpc_id     = local.create_vpc ? aws_vpc.this[0].id : data.aws_vpc.imported[0].id
  vpc_cidr   = local.create_vpc ? aws_vpc.this[0].cidr_block : data.aws_vpc.imported[0].cidr_block

  # ── Subnet CIDR layout ─────────────────────────────────────────────
  # Public subnets take the low /24s (10.0.0.0/24, 10.0.1.0/24, ...).
  # Private subnets take the /24s starting at index 128
  # (10.0.128.0/24, 10.0.129.0/24, ...). Keeps public/private ranges
  # visually distinguishable and reserves plenty of unused space for
  # future subnet types (isolated, database, etc.).
  public_subnet_cidrs  = [for i, _ in var.azs : cidrsubnet(var.vpc_cidr, 8, i)]
  private_subnet_cidrs = [for i, _ in var.azs : cidrsubnet(var.vpc_cidr, 8, i + 128)]

  # ── Source database ports ──────────────────────────────────────────
  # Standard JDBC set used by scan/enrichment pipelines. Ordered stably
  # so `for_each` doesn't churn keys on rearrangement.
  db_ports_standard = [1433, 1521, 3306, 5432, 5439] # +1521 (Oracle) for Lambda + connector SGs
  db_ports_jdbc     = [1433, 3306, 5432, 5439]       # peering/TGW egress (no 1521 per CDK)

  # ── VPC endpoint definitions ───────────────────────────────────────
  # Gateway endpoints — free, no ENI, no SG. Attach to private RTs.
  gateway_endpoints = {
    s3       = "com.amazonaws.${var.region}.s3"
    dynamodb = "com.amazonaws.${var.region}.dynamodb"
  }

  # Interface endpoints — private DNS enabled, HTTPS via ENI. Attach
  # to private subnets, SG is the AOSS SG (the only endpoint that
  # currently needs SG-scoped ingress; every other endpoint accepts
  # 443 from the VPC CIDR via its own default SG).
  #
  # Two AOSS endpoints (data-plane and control-plane) — the AOSS-data
  # service name has an `-data` suffix that no `com.amazonaws.<region>`
  # constant covers; the control-plane one is the bare `aoss` name.
  interface_endpoints = {
    athena             = "com.amazonaws.${var.region}.athena"
    aoss               = "com.amazonaws.${var.region}.aoss"      # control plane (create/delete collection)
    aoss_data          = "com.amazonaws.${var.region}.aoss-data" # data plane (search/ingest)
    bedrock_agentcore  = "com.amazonaws.${var.region}.bedrock-agentcore"
    bedrock_runtime    = "com.amazonaws.${var.region}.bedrock-runtime"
    cloudwatch_logs    = "com.amazonaws.${var.region}.logs"
    datazone           = "com.amazonaws.${var.region}.datazone"
    ecr_api            = "com.amazonaws.${var.region}.ecr.api"
    ecr_dkr            = "com.amazonaws.${var.region}.ecr.dkr"
    ecs                = "com.amazonaws.${var.region}.ecs"
    eventbridge        = "com.amazonaws.${var.region}.events"
    glue               = "com.amazonaws.${var.region}.glue"
    lambda             = "com.amazonaws.${var.region}.lambda"
    neptune_analytics  = "com.amazonaws.${var.region}.neptune-graph"
    neptune_graph_data = "com.amazonaws.${var.region}.neptune-graph-data"
    secrets_manager    = "com.amazonaws.${var.region}.secretsmanager"
    sqs                = "com.amazonaws.${var.region}.sqs"
    ssm                = "com.amazonaws.${var.region}.ssm"
    step_functions     = "com.amazonaws.${var.region}.states"
    sts                = "com.amazonaws.${var.region}.sts"
  }

  # ── JDBC connectivity toggles ──────────────────────────────────────
  peering_enabled     = var.jdbc_peer_vpc_id != null
  tgw_enabled         = var.jdbc_tgw_id != null
  privatelink_enabled = var.jdbc_privatelink_service != null

  # Route entries: cross-product of (private route table, destination CIDR)
  # rendered as a stable-keyed map for for_each. Only used when the
  # corresponding connectivity is enabled.
  peering_route_keys = local.peering_enabled ? flatten([
    for az_key, _ in aws_route_table.private : [
      for cidr in var.jdbc_peer_cidrs : {
        key  = "${az_key}-${cidr}"
        az   = az_key
        cidr = cidr
      }
    ]
  ]) : []

  tgw_route_keys = local.tgw_enabled ? flatten([
    for az_key, _ in aws_route_table.private : [
      for cidr in var.jdbc_tgw_cidrs : {
        key  = "${az_key}-${cidr}"
        az   = az_key
        cidr = cidr
      }
    ]
  ]) : []

  # ── Egress rules on client SGs for peering/TGW destination CIDRs ──
  # Cross-product of (client SG, destination CIDR, DB port) — needed
  # only when the destination is NOT covered by the SG's existing
  # anywhere-scoped rules. Locked-down SGs (`allowAllOutbound: false`
  # in CDK) require the explicit rule; open SGs would treat this as
  # a no-op. Terraform does not dedupe, so gate on locked-down clients.
  jdbc_egress_cidrs = concat(var.jdbc_peer_cidrs, var.jdbc_tgw_cidrs)

  # Client SGs that need JDBC egress rules added: connector and lambda
  # (both allowAllOutbound: false in the CDK). ECS is the platform's
  # own tasks — they don't talk to source databases directly.
  jdbc_client_sg_keys = ["connector", "lambda"]

  jdbc_egress_rules = length(local.jdbc_egress_cidrs) > 0 ? {
    for r in flatten([
      for sg_key in local.jdbc_client_sg_keys : [
        for cidr in local.jdbc_egress_cidrs : [
          for port in local.db_ports_jdbc : {
            key    = "${sg_key}-${cidr}-${port}"
            sg_key = sg_key
            cidr   = cidr
            port   = port
          }
        ]
      ]
    ]) : r.key => r
  } : {}
}
