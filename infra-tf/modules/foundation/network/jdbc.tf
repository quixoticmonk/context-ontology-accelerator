# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Cross-network JDBC connectivity — VPC peering, Transit Gateway,
# PrivateLink. Any combination is supported. Only provisioned when
# this module creates the VPC (imported VPCs bring their own peering
# / TGW / PrivateLink managed externally, matching the CDK behavior).
#
# Validation on the (config-set, cidrs-set) pairs happens through
# check blocks below. When jdbc_peer_vpc_id is set but jdbc_peer_cidrs
# is empty, TF plan produces an empty route set and the intent is
# silently dropped — the check surfaces the misconfig as a warning.

check "peering_requires_cidrs" {
  assert {
    condition     = var.jdbc_peer_vpc_id == null || length(var.jdbc_peer_cidrs) > 0
    error_message = "jdbc_peer_vpc_id requires jdbc_peer_cidrs to be non-empty."
  }
}

check "tgw_requires_cidrs" {
  assert {
    condition     = var.jdbc_tgw_id == null || length(var.jdbc_tgw_cidrs) > 0
    error_message = "jdbc_tgw_id requires jdbc_tgw_cidrs to be non-empty."
  }
}

check "privatelink_requires_port" {
  assert {
    condition     = var.jdbc_privatelink_service == null || (var.jdbc_privatelink_port != null && var.jdbc_privatelink_port > 0 && var.jdbc_privatelink_port < 65536)
    error_message = "jdbc_privatelink_service requires jdbc_privatelink_port to be an integer 1-65535."
  }
}

# ═════════════════════════════════════════════════════════════════════
#  VPC Peering
# ═════════════════════════════════════════════════════════════════════

resource "aws_vpc_peering_connection" "this" {
  count = local.create_vpc && local.peering_enabled ? 1 : 0

  vpc_id        = local.vpc_id
  peer_vpc_id   = var.jdbc_peer_vpc_id
  peer_owner_id = var.jdbc_peer_owner_id
  peer_region   = var.jdbc_peer_region

  tags = {
    Name      = "${var.name_prefix}-jdbc-peering"
    Component = var.component
  }
}

resource "aws_route" "peering" {
  for_each = { for r in local.peering_route_keys : r.key => r }

  route_table_id            = aws_route_table.private[each.value.az].id
  destination_cidr_block    = each.value.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.this[0].id
}

# ═════════════════════════════════════════════════════════════════════
#  Transit Gateway attachment
# ═════════════════════════════════════════════════════════════════════

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  count = local.create_vpc && local.tgw_enabled ? 1 : 0

  transit_gateway_id = var.jdbc_tgw_id
  vpc_id             = local.vpc_id
  subnet_ids         = [for s in aws_subnet.private : s.id]

  tags = {
    Name      = "${var.name_prefix}-jdbc-tgw-attachment"
    Component = var.component
  }
}

resource "aws_route" "tgw" {
  for_each = { for r in local.tgw_route_keys : r.key => r }

  route_table_id         = aws_route_table.private[each.value.az].id
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = var.jdbc_tgw_id

  # The route cannot resolve until the VPC is attached to the TGW.
  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}

# ═════════════════════════════════════════════════════════════════════
#  Client SG egress rules for peering/TGW destination CIDRs
# ═════════════════════════════════════════════════════════════════════
# `lambda` and `connector` SGs have `allowAllOutbound: false`
# equivalent behavior (explicit egress rules), so remote-CIDR JDBC
# traffic on DB ports needs an explicit egress rule added.

resource "aws_vpc_security_group_egress_rule" "jdbc_client_egress" {
  for_each = local.jdbc_egress_rules

  security_group_id = each.value.sg_key == "lambda" ? aws_security_group.lambda.id : aws_security_group.connector.id
  cidr_ipv4         = each.value.cidr
  ip_protocol       = "tcp"
  from_port         = each.value.port
  to_port           = each.value.port
  description       = "JDBC ${each.value.port} to peer/TGW ${each.value.cidr}"

  tags = { Component = var.component }
}

# ═════════════════════════════════════════════════════════════════════
#  PrivateLink endpoint
# ═════════════════════════════════════════════════════════════════════

resource "aws_security_group" "privatelink" {
  count = local.create_vpc && local.privatelink_enabled ? 1 : 0

  name        = "${var.name_prefix}-jdbc-privatelink-sg"
  description = "JDBC PrivateLink endpoint - inbound from connector clients"
  vpc_id      = local.vpc_id

  tags = {
    Name      = "${var.name_prefix}-jdbc-privatelink-sg"
    Component = var.component
  }

  lifecycle { create_before_destroy = true }
}

# Only connector + lambda SGs may reach the endpoint, on the DB port.
resource "aws_vpc_security_group_ingress_rule" "privatelink_from_lambda" {
  count = local.create_vpc && local.privatelink_enabled ? 1 : 0

  security_group_id            = aws_security_group.privatelink[0].id
  referenced_security_group_id = aws_security_group.lambda.id
  ip_protocol                  = "tcp"
  from_port                    = var.jdbc_privatelink_port
  to_port                      = var.jdbc_privatelink_port
  description                  = "JDBC PrivateLink from Lambda"

  tags = { Component = var.component }
}

resource "aws_vpc_security_group_ingress_rule" "privatelink_from_connector" {
  count = local.create_vpc && local.privatelink_enabled ? 1 : 0

  security_group_id            = aws_security_group.privatelink[0].id
  referenced_security_group_id = aws_security_group.connector.id
  ip_protocol                  = "tcp"
  from_port                    = var.jdbc_privatelink_port
  to_port                      = var.jdbc_privatelink_port
  description                  = "JDBC PrivateLink from connector"

  tags = { Component = var.component }
}

resource "aws_vpc_endpoint" "jdbc_privatelink" {
  count = local.create_vpc && local.privatelink_enabled ? 1 : 0

  vpc_id              = local.vpc_id
  service_name        = var.jdbc_privatelink_service
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = var.jdbc_privatelink_private_dns
  subnet_ids          = [for s in aws_subnet.private : s.id]
  security_group_ids  = [aws_security_group.privatelink[0].id]

  tags = {
    Name      = "${var.name_prefix}-jdbc-privatelink"
    Component = var.component
  }
}
