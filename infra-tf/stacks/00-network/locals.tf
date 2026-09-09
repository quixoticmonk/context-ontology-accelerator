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
}

data "aws_availability_zones" "this" {
  state = "available"
}

# The service name follows the region; missing in unsupported regions.
data "aws_vpc_endpoint_service" "aoss" {
  count        = local.restricted_zone_ids == null ? 0 : 1
  service_name = "com.amazonaws.${var.region}.aoss"
}

# Fail-loud at plan time (matches CDK's `throw new Error`).
check "agentcore_az_count" {
  assert {
    condition     = local.restricted_zone_ids == null || length(local.resolved_azs) >= 2
    error_message = "Region ${var.region} resolved only ${length(local.agentcore_supported_az_names_raw)} AgentCore-supported AZ(s) intersected with AOSS: [${join(", ", local.agentcore_supported_az_names_raw)}]. Need ≥2. Supported zone IDs: [${join(", ", local.restricted_zone_ids)}]. Verify with `aws ec2 describe-availability-zones --region ${var.region}`."
  }
}
