# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  name_prefix = "${var.resource_prefix}-${var.env}"
  ssm_prefix  = "/${var.resource_prefix}"

  common_tags = {
    Environment = var.env
    ManagedBy   = "Terraform"
    Project     = var.project_tag
  }

  # ── VPC path selector ────────────────────────────────────────────
  create_vpc = var.vpc_name == null

  # ── AgentCore AZ resolution (mirrors CDK `resolveAgentCoreAzNames`) ─
  # AgentCore Runtime is only offered in a subset of physical zones in
  # some regions. Hardcode zone IDs (stable across accounts) and resolve
  # to friendly names (account-specific) at plan time.
  # Update this map as AWS expands AgentCore AZ coverage.
  agentcore_supported_zone_ids = {
    "us-east-1" = ["use1-az1", "use1-az2", "use1-az4"]
  }
  restricted_zone_ids = try(local.agentcore_supported_zone_ids[var.region], null)

  # OpenSearch Serverless control-plane VPC endpoint is offered in a
  # different subset of AZs. Intersect the two so the VPC lands where
  # both services work (matches CDK `resolveEndpointServiceAzNames`).
  # If the endpoint service doesn't exist yet in this account, treat
  # every AZ as valid — same behavior as the CDK's undefined fallback.
  aoss_endpoint_supported_azs = try(
    tolist(data.aws_vpc_endpoint_service.aoss[0].availability_zones),
    null,
  )

  # AgentCore-supported AZ names in this account, intersected with the
  # AOSS endpoint's AZs when available. sort() gives deterministic order.
  agentcore_supported_az_names_raw = local.restricted_zone_ids == null ? data.aws_availability_zones.this.names : sort([
    for i, zid in data.aws_availability_zones.this.zone_ids :
    data.aws_availability_zones.this.names[i]
    if contains(local.restricted_zone_ids, zid) && (
      local.aoss_endpoint_supported_azs == null ||
      contains(local.aoss_endpoint_supported_azs, data.aws_availability_zones.this.names[i])
    )
  ])

  # Deploy in the first 2 (matches CDK's `count = 2` default). Downstream
  # services get all of these via SSM — HA services can consume ≥2.
  resolved_azs = slice(local.agentcore_supported_az_names_raw, 0, min(2, length(local.agentcore_supported_az_names_raw)))

  # ── Effective AZs passed to the network module ───────────────────
  # Create-VPC path: honor the resolver in restricted regions, fall
  # back to the user-provided list in unrestricted ones. BYOVPC path:
  # pass an empty list — the module ignores `azs` and reads AZs from
  # the provided private subnets instead.
  effective_azs = local.create_vpc ? (
    local.restricted_zone_ids == null ? var.azs : local.resolved_azs
  ) : []
}

data "aws_availability_zones" "this" {
  state = "available"
}

# The service name follows the region; missing in unsupported regions.
data "aws_vpc_endpoint_service" "aoss" {
  count        = local.restricted_zone_ids == null ? 0 : 1
  service_name = "com.amazonaws.${var.region}.aoss"
}

# ── AgentCore AZ assertions ────────────────────────────────────────
# Create-VPC mode: fail plan if the region resolves fewer than 2
# AgentCore-supported AZs (the CDK's `throw new Error` equivalent).
# BYOVPC mode: warn if any of the customer's private subnets are in
# an AZ that AgentCore does not support. This is an advisory check
# (Terraform `check` blocks warn but do not block apply) — downstream
# stack 50-agentcore reads the AZ list from SSM and will produce a
# concrete failure at that layer if AgentCore cannot be provisioned.

check "agentcore_az_count" {
  assert {
    condition     = !local.create_vpc || local.restricted_zone_ids == null || length(local.resolved_azs) >= 2
    error_message = "Region ${var.region} resolved only ${length(local.agentcore_supported_az_names_raw)} AgentCore-supported AZ(s) intersected with AOSS: [${join(", ", local.agentcore_supported_az_names_raw)}]. Need ≥2. Supported zone IDs: [${join(", ", coalesce(local.restricted_zone_ids, []))}]. Verify with `aws ec2 describe-availability-zones --region ${var.region}`."
  }
}

check "agentcore_az_supported_byovpc" {
  assert {
    condition = local.create_vpc || local.restricted_zone_ids == null || alltrue([
      for az in module.network.private_subnet_azs :
      contains(local.agentcore_supported_az_names_raw, az)
    ])
    error_message = "One or more customer-provided private subnets are in AZs that are not AgentCore-supported. Provided subnet AZs: [${join(", ", module.network.private_subnet_azs)}]. AgentCore-supported AZs in ${var.region}: [${join(", ", local.agentcore_supported_az_names_raw)}]. AgentCore Runtime provisioning in stack 50-agentcore will fail unless the subnets are moved to supported AZs."
  }
}
