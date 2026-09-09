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
# Every interface endpoint attaches to private subnets. The default
# endpoint SG (created implicitly by AWS) accepts 443 from the VPC
# CIDR, which is what the CDK relies on. AOSS has an ADDITIONAL
# dedicated SG (see security_groups.tf) so ingress can be scoped to
# specific client SGs; we attach that SG here to the AOSS endpoints.

resource "aws_vpc_endpoint" "interface" {
  for_each = local.create_vpc ? local.interface_endpoints : {}

  vpc_id              = local.vpc_id
  service_name        = each.value
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for s in aws_subnet.private : s.id]

  # Attach the AOSS SG to both AOSS endpoints so consumers can be
  # granted access by adding an ingress rule to `aws_security_group.aoss`.
  # Every other endpoint uses the default VPC endpoint SG.
  security_group_ids = contains(["aoss", "aoss_data"], each.key) ? [aws_security_group.aoss.id] : null

  tags = {
    Name      = "${var.name_prefix}-vpce-${replace(each.key, "_", "-")}"
    Component = var.component
  }
}
