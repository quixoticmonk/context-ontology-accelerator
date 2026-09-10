# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# VPC endpoints. Only created when this module creates the VPC —
# imported VPCs are expected to have their endpoints managed externally,
# matching the CDK's behavior (`if (!existingVpcId)` branch).
#
# Gateway endpoints (S3, DynamoDB) attach to every private route table
# and cost nothing. Interface endpoints (Bedrock, ECR, SSM, ...) have
# an hourly + per-GB charge — the set below matches what CDK provisions.

# ── Gateway endpoints ──────────────────────────────────────────────
resource "aws_vpc_endpoint" "gateway" {
  for_each = local.create_vpc ? local.gateway_endpoints : {}

  vpc_id            = local.vpc_id
  service_name      = each.value
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.private : rt.id]

  tags = {
    Name      = "${var.name_prefix}-vpce-${each.key}"
    Component = var.component
  }
}

# ── Interface endpoints ────────────────────────────────────────────
# Every interface endpoint attaches to private subnets. When no SG is
# specified TF/AWS attaches the VPC's default SG — which only allows
# ingress from itself, NOT from the VPC CIDR. Since Lambda/ECS/etc.
# run under their own SGs, they'd be silently dropped at the endpoint's
# SG. Explicitly attach `interface_endpoints` SG which allows 443
# from the VPC CIDR. AOSS gets its OWN SG (see security_groups.tf) so
# ingress can be scoped to specific client SGs.

resource "aws_security_group" "interface_endpoints" {
  count       = local.create_vpc ? 1 : 0
  name        = "${var.name_prefix}-vpce-interface-sg"
  description = "Shared SG for AWS-service interface VPC endpoints. Allows 443 from VPC CIDR."
  vpc_id      = local.vpc_id

  tags = {
    Name      = "${var.name_prefix}-vpce-interface-sg"
    Component = var.component
  }
}

resource "aws_vpc_security_group_ingress_rule" "interface_endpoints_https_from_vpc" {
  count = local.create_vpc ? 1 : 0

  security_group_id = aws_security_group.interface_endpoints[0].id
  cidr_ipv4         = aws_vpc.this[0].cidr_block
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS from VPC CIDR (Lambda/ECS/AgentCore/etc. reach AWS APIs)"

  tags = {
    Component = var.component
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.create_vpc ? local.interface_endpoints : {}

  vpc_id              = local.vpc_id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in aws_subnet.private : s.id]

  # AOSS endpoints use the AOSS SG so clients can be granted access by
  # adding an ingress rule to `aws_security_group.aoss`. All other
  # endpoints use the shared interface_endpoints SG (443 from VPC CIDR).
  security_group_ids = contains(["aoss", "aoss_data"], each.key) ? [aws_security_group.aoss.id] : [aws_security_group.interface_endpoints[0].id]

  tags = {
    Name      = "${var.name_prefix}-vpce-${replace(each.key, "_", "-")}"
    Component = var.component
  }
}
