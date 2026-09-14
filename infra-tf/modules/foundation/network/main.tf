# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# VPC, subnets, IGW, NAT, route tables, and Cloud Map namespace.
# Every networking primitive is gated by an independent create_* flag
# (see variables.tf); the flags default to `local.create_vpc`, so a
# module call that provides `vpc_id` gets an imported VPC with no
# module-managed IGW/NAT/route tables/endpoints by default. Individual
# flags can be flipped to have this module manage a subset of those
# primitives inside a customer's VPC.

# ── Data sources for imported VPC + subnets ────────────────────────
# BYOVPC lookup is name-driven:
#   - the VPC is resolved by exactly-matching its tag:Name
#     (data.aws_vpc fails loudly if the filter matches more than one)
#   - private subnets are resolved by wildcard-matching their tag:Name
#     against var.private_subnet_name_pattern within that VPC
#     (data.aws_subnets returns an empty list on no match, which
#     surfaces as a length-0 subnet_ids output and fails downstream
#     resources — Neptune subnet group, TGW attachment, etc. — with
#     a clearer error than a data-source-not-found)
data "aws_vpc" "imported" {
  count = local.create_vpc ? 0 : 1

  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

data "aws_subnets" "imported_private" {
  count = local.create_vpc ? 0 : 1

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.imported[0].id]
  }

  filter {
    name   = "tag:Name"
    values = [var.private_subnet_name_pattern]
  }
}

data "aws_subnet" "imported_private" {
  for_each = local.create_vpc ? toset([]) : toset(data.aws_subnets.imported_private[0].ids)
  id       = each.value
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
  count = local.create_igw ? 1 : 0

  vpc_id = local.vpc_id

  tags = {
    Name      = "${var.name_prefix}-igw"
    Component = var.component
  }
}

# ── NAT gateway ────────────────────────────────────────────────────
# Single NAT (matches CDK `natGateways: 1`). Placed in the first
# public subnet — sorted key order is stable across plans.
resource "aws_eip" "nat" {
  count = local.create_nat_gateway ? 1 : 0

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
  count = local.create_nat_gateway ? 1 : 0

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
#
# The default routes are further gated on their upstream targets so a
# caller can enable route tables without NAT (or without IGW) if they
# have a different egress model — the RTs are created, the platform's
# private subnets are associated, but no `0.0.0.0/0` route is added.

resource "aws_route_table" "public" {
  count = local.create_route_tables ? 1 : 0

  vpc_id = local.vpc_id

  tags = {
    Name      = "${var.name_prefix}-public-rt"
    Component = var.component
  }
}

resource "aws_route" "public_default" {
  count = local.create_route_tables && local.create_igw ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public" {
  for_each = local.create_route_tables ? aws_subnet.public : {}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[0].id
}

resource "aws_route_table" "private" {
  for_each = local.create_route_tables ? aws_subnet.private : {}

  vpc_id = local.vpc_id

  tags = {
    Name      = "${var.name_prefix}-private-rt-${each.key}"
    Component = var.component
    Tier      = "private"
  }
}

resource "aws_route" "private_default" {
  for_each = local.create_route_tables && local.create_nat_gateway ? aws_route_table.private : {}

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}

resource "aws_route_table_association" "private" {
  for_each = local.create_route_tables ? aws_subnet.private : {}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# ── Cloud Map service-discovery namespace ──────────────────────────
# Shared private DNS namespace: `${prefix}-services.local`. Every
# in-VPC HTTP service that other services address by name (ontology-
# engine, VKG per-namespace instances) registers under this namespace.
# Gated by `create_service_discovery_namespace` (default true) so a
# deployment consuming an externally-managed namespace can turn it off
# and let the caller supply the id/name via SSM directly.
resource "aws_service_discovery_private_dns_namespace" "this" {
  count = var.create_service_discovery_namespace ? 1 : 0

  name = "${var.name_prefix}-services.local"
  vpc  = local.vpc_id

  tags = {
    Name      = "${var.name_prefix}-services"
    Component = var.component
  }
}

# ── SSM: VPC + subnet metadata for runtime consumers ───────────────
# VPC ID is always published (imported or created). Cloud Map
# namespace ID/name are only published when this module creates the
# namespace; consumers of an external namespace write those SSM
# parameters themselves.

resource "aws_ssm_parameter" "vpc_id" {
  name  = "${var.ssm_prefix}/network/vpc-id"
  type  = "String"
  value = local.vpc_id

  tags = { Component = var.component }
}

resource "aws_ssm_parameter" "service_namespace_id" {
  count = var.create_service_discovery_namespace ? 1 : 0

  name  = "${var.ssm_prefix}/network/service-namespace-id"
  type  = "String"
  value = aws_service_discovery_private_dns_namespace.this[0].id

  tags = { Component = var.component }
}

resource "aws_ssm_parameter" "service_namespace_name" {
  count = var.create_service_discovery_namespace ? 1 : 0

  name  = "${var.ssm_prefix}/network/service-namespace-name"
  type  = "String"
  value = aws_service_discovery_private_dns_namespace.this[0].name

  tags = { Component = var.component }
}
