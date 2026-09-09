# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# VPC, subnets, IGW, NAT, route tables, and Cloud Map namespace.
# Every resource is created only when `var.vpc_id == null` (the create
# path); the import path uses a data source and delegates VPC-endpoint
# and route-table management to whoever owns the imported VPC.

# ── Data source for imported VPC ────────────────────────────────────
data "aws_vpc" "imported" {
  count = local.create_vpc ? 0 : 1
  id    = var.vpc_id
}

# ── VPC ────────────────────────────────────────────────────────────
resource "aws_vpc" "this" {
  count = local.create_vpc ? 1 : 0

  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name      = "${var.name_prefix}-vpc"
    Component = var.component
  }
}

# ── Subnets ────────────────────────────────────────────────────────
# One public + one private subnet per AZ. Public subnets host the NAT
# gateway and any future internet-facing ALB; private subnets host every
# Lambda, ECS task, VPC endpoint, and database.
#
# Names carry the AZ suffix (`-public-us-east-1b`) so they're identifiable
# in the console without expanding the details pane.

resource "aws_subnet" "public" {
  for_each = local.create_vpc ? { for i, az in var.azs : az => local.public_subnet_cidrs[i] } : {}

  vpc_id                  = aws_vpc.this[0].id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = {
    Name      = "${var.name_prefix}-public-${each.key}"
    Component = var.component
    Tier      = "public"
  }
}

resource "aws_subnet" "private" {
  for_each = local.create_vpc ? { for i, az in var.azs : az => local.private_subnet_cidrs[i] } : {}

  vpc_id            = aws_vpc.this[0].id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name      = "${var.name_prefix}-private-${each.key}"
    Component = var.component
    Tier      = "private"
  }
}

# ── Internet gateway ───────────────────────────────────────────────
resource "aws_internet_gateway" "this" {
  count = local.create_vpc ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  tags = {
    Name      = "${var.name_prefix}-igw"
    Component = var.component
  }
}

# ── NAT gateway ────────────────────────────────────────────────────
# Single NAT (matches CDK `natGateways: 1`). Placed in the first
# public subnet — sorted key order is stable across plans.
resource "aws_eip" "nat" {
  count = local.create_vpc ? 1 : 0

  domain = "vpc"

  tags = {
    Name      = "${var.name_prefix}-nat-eip"
    Component = var.component
  }

  # NAT EIP allocation depends on IGW being present in the VPC; without
  # this AWS returns InvalidAllocationID.NotFound on first apply.
  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = local.create_vpc ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[sort(keys(aws_subnet.public))[0]].id

  tags = {
    Name      = "${var.name_prefix}-nat"
    Component = var.component
  }

  depends_on = [aws_internet_gateway.this]
}

# ── Route tables ───────────────────────────────────────────────────
# Single public RT (default route → IGW). One private RT per AZ so
# per-AZ routes (peering, TGW, custom NAT policies) don't step on each
# other; today they all share the same NAT default route.

resource "aws_route_table" "public" {
  count = local.create_vpc ? 1 : 0

  vpc_id = aws_vpc.this[0].id

  tags = {
    Name      = "${var.name_prefix}-public-rt"
    Component = var.component
  }
}

resource "aws_route" "public_default" {
  count = local.create_vpc ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private

  vpc_id = aws_vpc.this[0].id

  tags = {
    Name      = "${var.name_prefix}-private-rt-${each.key}"
    Component = var.component
    Tier      = "private"
  }
}

resource "aws_route" "private_default" {
  for_each = aws_route_table.private

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# ── Cloud Map service-discovery namespace ──────────────────────────
# Shared private DNS namespace: `${prefix}-services.local`. Every
# in-VPC HTTP service that other services address by name (ontology-
# engine, VKG per-namespace instances) registers under this namespace.
resource "aws_service_discovery_private_dns_namespace" "this" {
  name = "${var.name_prefix}-services.local"
  vpc  = local.vpc_id

  tags = {
    Name      = "${var.name_prefix}-services"
    Component = var.component
  }
}

# ── SSM: VPC + subnet metadata for runtime consumers ───────────────
# Not strictly required (modules can pass IDs directly), but the CDK
# publishes some of these via CfnOutput and the destroy script reads
# them; keeping parity avoids surprises when the shell scripts run.

resource "aws_ssm_parameter" "vpc_id" {
  name  = "${var.ssm_prefix}/network/vpc-id"
  type  = "String"
  value = local.vpc_id

  tags = { Component = var.component }
}

resource "aws_ssm_parameter" "service_namespace_id" {
  name  = "${var.ssm_prefix}/network/service-namespace-id"
  type  = "String"
  value = aws_service_discovery_private_dns_namespace.this.id

  tags = { Component = var.component }
}

resource "aws_ssm_parameter" "service_namespace_name" {
  name  = "${var.ssm_prefix}/network/service-namespace-name"
  type  = "String"
  value = aws_service_discovery_private_dns_namespace.this.name

  tags = { Component = var.component }
}
