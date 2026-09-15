# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Five security groups matching the CDK network stack:
#   1. neptune   — DB target; ingress from ECS + Lambda on 8182
#   2. ecs       — Fargate tasks; egress to Neptune 8182 + anywhere 443
#   3. lambda    — Functions; egress to Neptune 8182 + ECS 8001 + DB ports + 443
#   4. aoss      — AOSS VPC endpoint; ingress from ECS on 443
#   5. connector — Glue connectors; self-referencing + DB ports + OCSP 80 + 443
#
# Rules use v6-style discrete resources
# (`aws_vpc_security_group_ingress_rule` / `_egress_rule`) rather than
# inline `ingress`/`egress` blocks per the style guide, so diffs are
# per-rule instead of full-block replacements.

# ═════════════════════════════════════════════════════════════════════
#  1. Neptune SG — database target
# ═════════════════════════════════════════════════════════════════════

resource "aws_security_group" "neptune" {
  # checkov:skip=CKV2_AWS_5:Attached to the Neptune cluster in modules/foundation/storage via var.neptune_security_group_id (read from SSM by consuming stacks). Cross-module attachment not visible to checkov's static analysis.
  name        = "${var.name_prefix}-neptune-sg"
  description = "Neptune cluster security group"
  vpc_id      = local.vpc_id

  tags = {
    Name      = "${var.name_prefix}-neptune-sg"
    Component = var.component
  }

  # `revoke_rules_on_delete` in AWS provider v6 is off by default;
  # ingress/egress rules are owned by their own resources so this
  # bare SG has no inline rules to revoke either way.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "neptune_from_ecs" {
  security_group_id            = aws_security_group.neptune.id
  referenced_security_group_id = aws_security_group.ecs.id
  ip_protocol                  = "tcp"
  from_port                    = 8182
  to_port                      = 8182
  description                  = "Neptune Gremlin/SPARQL from ECS tasks"

  tags = { Component = var.component }
}

resource "aws_vpc_security_group_ingress_rule" "neptune_from_lambda" {
  security_group_id            = aws_security_group.neptune.id
  referenced_security_group_id = aws_security_group.lambda.id
  ip_protocol                  = "tcp"
  from_port                    = 8182
  to_port                      = 8182
  description                  = "Neptune Gremlin/SPARQL from Lambda functions"

  tags = { Component = var.component }
}

# No egress rules — Neptune is a target, never initiates.

# ═════════════════════════════════════════════════════════════════════
#  2. ECS SG — Fargate tasks
# ═════════════════════════════════════════════════════════════════════

resource "aws_security_group" "ecs" {
  # checkov:skip=CKV2_AWS_5:Attached to every ECS Fargate service (vkg, ontology, sources/db-enrichment, sources/kg-build) via var.ecs_security_group_id. 14 consumers across the repo.
  name        = "${var.name_prefix}-ecs-sg"
  description = "ECS Fargate tasks security group"
  vpc_id      = local.vpc_id

  tags = {
    Name      = "${var.name_prefix}-ecs-sg"
    Component = var.component
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_egress_rule" "ecs_https_anywhere" {
  security_group_id = aws_security_group.ecs.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS to AWS APIs (interface endpoints + S3/DDB gateway prefix lists)"

  tags = { Component = var.component }
}

resource "aws_vpc_security_group_egress_rule" "ecs_to_neptune" {
  security_group_id            = aws_security_group.ecs.id
  referenced_security_group_id = aws_security_group.neptune.id
  ip_protocol                  = "tcp"
  from_port                    = 8182
  to_port                      = 8182
  description                  = "Neptune Gremlin/SPARQL"

  tags = { Component = var.component }
}

# ═════════════════════════════════════════════════════════════════════
#  3. Lambda SG — functions
# ═════════════════════════════════════════════════════════════════════

resource "aws_security_group" "lambda" {
  # checkov:skip=CKV2_AWS_5:Attached to every Lambda function's vpc_config via var.lambda_security_group_id. 35 consumers across the repo (every aws_lambda_function that runs in-VPC).
  name        = "${var.name_prefix}-lambda-sg"
  description = "Lambda functions security group"
  vpc_id      = local.vpc_id

  tags = {
    Name      = "${var.name_prefix}-lambda-sg"
    Component = var.component
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_egress_rule" "lambda_https_anywhere" {
  security_group_id = aws_security_group.lambda.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS to AWS APIs (interface endpoints + S3/DDB gateway prefix lists)"

  tags = { Component = var.component }
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_neptune" {
  security_group_id            = aws_security_group.lambda.id
  referenced_security_group_id = aws_security_group.neptune.id
  ip_protocol                  = "tcp"
  from_port                    = 8182
  to_port                      = 8182
  description                  = "Neptune Gremlin/SPARQL"

  tags = { Component = var.component }
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_ecs_ontology_api" {
  security_group_id            = aws_security_group.lambda.id
  referenced_security_group_id = aws_security_group.ecs.id
  ip_protocol                  = "tcp"
  from_port                    = 8001
  to_port                      = 8001
  description                  = "Ontology-engine API: api-proxy Lambda to ECS Cloud Map service"

  tags = { Component = var.component }
}

# Direct JDBC discovery: the sources-db-connector Lambda talks to
# customer databases via native drivers (not Glue/Athena), so it
# needs egress on each supported DB port to anywhere.
resource "aws_vpc_security_group_egress_rule" "lambda_db_ports" {
  for_each = toset([for p in local.db_ports_standard : tostring(p)])

  security_group_id = aws_security_group.lambda.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  description       = "Source database ${each.value} (direct JDBC discovery)"

  tags = { Component = var.component }
}

# ═════════════════════════════════════════════════════════════════════
#  4. AOSS VPC endpoint SG — ingress-gated by consumer SGs
# ═════════════════════════════════════════════════════════════════════

resource "aws_security_group" "aoss" {
  name        = "${var.name_prefix}-aoss-vpce-sg"
  description = "AOSS VPC endpoint - accept HTTPS from authorized components"
  vpc_id      = local.vpc_id

  tags = {
    Name      = "${var.name_prefix}-aoss-vpce-sg"
    Component = var.component
  }

  lifecycle { create_before_destroy = true }
}

resource "aws_vpc_security_group_ingress_rule" "aoss_from_ecs" {
  security_group_id            = aws_security_group.aoss.id
  referenced_security_group_id = aws_security_group.ecs.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS from ECS tasks"

  tags = { Component = var.component }
}

# Additional consumers (Lambda authorizer, serve AgentCore) add their
# own ingress rules by attaching to this SG in their modules.

# ═════════════════════════════════════════════════════════════════════
#  5. Connector SG — Glue/Athena federation to source databases
# ═════════════════════════════════════════════════════════════════════

resource "aws_security_group" "connector" {
  # checkov:skip=CKV2_AWS_5:Attached to Glue Connections and Athena federation connectors in modules/services/sources via var.connector_security_group_id. Used by the federated_catalog role for outbound to source databases.
  name        = "${var.name_prefix}-connector-sg"
  description = "Glue Connection / Athena connector - outbound to source databases"
  vpc_id      = local.vpc_id

  tags = {
    Name      = "${var.name_prefix}-connector-sg"
    Component = var.component
  }

  lifecycle { create_before_destroy = true }
}

# Glue managed connectors require self-reference on both directions
# for inter-ENI communication during connection validation and query
# execution. Under `allowAllOutbound` the egress side is implicit;
# with egress locked down it must be declared explicitly.
resource "aws_vpc_security_group_ingress_rule" "connector_self" {
  security_group_id            = aws_security_group.connector.id
  referenced_security_group_id = aws_security_group.connector.id
  ip_protocol                  = "-1"
  description                  = "Glue connector self-reference (ingress)"

  tags = { Component = var.component }
}

resource "aws_vpc_security_group_egress_rule" "connector_self" {
  security_group_id            = aws_security_group.connector.id
  referenced_security_group_id = aws_security_group.connector.id
  ip_protocol                  = "-1"
  description                  = "Glue connector self-reference (egress)"

  tags = { Component = var.component }
}

# Source-DB egress. Cross-product of (peer CIDR OR 0.0.0.0/0, DB port).
# When `connector_egress_cidrs` is empty (default), egress is anywhere;
# when set, it's scoped to those CIDRs. Same shape as `jdbc_peer_cidrs`
# on the JDBC connectivity construct.
locals {
  connector_egress_peers = length(var.connector_egress_cidrs) > 0 ? var.connector_egress_cidrs : ["0.0.0.0/0"]

  connector_db_egress = {
    for r in flatten([
      for cidr in local.connector_egress_peers : [
        for port in local.db_ports_standard : {
          key  = "${cidr}-${port}"
          cidr = cidr
          port = port
        }
      ]
    ]) : r.key => r
  }

  connector_https_egress = {
    for cidr in local.connector_egress_peers : cidr => cidr
  }
}

resource "aws_vpc_security_group_egress_rule" "connector_db_ports" {
  for_each = local.connector_db_egress

  security_group_id = aws_security_group.connector.id
  cidr_ipv4         = each.value.cidr
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  description       = "Source database ${each.value.port} to ${each.value.cidr}"

  tags = { Component = var.component }
}

# HTTPS: Snowflake wire protocol + AWS APIs (Glue/S3/STS).
resource "aws_vpc_security_group_egress_rule" "connector_https" {
  for_each = local.connector_https_egress

  security_group_id = aws_security_group.connector.id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS to ${each.value} (Snowflake + AWS APIs)"

  tags = { Component = var.component }
}

# OCSP certificate revocation. Only the Snowflake driver does internet
# OCSP; every other engine talks to a private endpoint. Optional so
# deployments with no Snowflake source can drop it via
# `var.connector_ocsp_egress = false`. Without it, Snowflake connects
# soft-fail with ~5-30s per-responder latency (measured 184s
# ValidationLatency against a 900s Lambda timeout on scan).
resource "aws_vpc_security_group_egress_rule" "connector_ocsp" {
  for_each = var.connector_ocsp_egress ? local.connector_https_egress : {}

  security_group_id = aws_security_group.connector.id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  description       = "OCSP certificate revocation (HTTP-only protocol) to ${each.value}"

  tags = { Component = var.component }
}
