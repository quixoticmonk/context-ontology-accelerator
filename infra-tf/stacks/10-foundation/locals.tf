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

  custom_domain_fields = {
    ui_domain_name      = var.ui_domain_name
    ui_certificate_arn  = var.ui_certificate_arn
    api_domain_name     = var.api_domain_name
    api_certificate_arn = var.api_certificate_arn
    hosted_zone_id      = var.hosted_zone_id
  }

  custom_domain_set_count = length([
    for v in values(local.custom_domain_fields) : v if v != null
  ])

  custom_domain_enabled = local.custom_domain_set_count == length(local.custom_domain_fields)

  allowed_origin = local.custom_domain_enabled ? "https://${var.ui_domain_name}" : "*"

  # Read from 00-network SSM
  aoss_security_group_id    = data.aws_ssm_parameter.aoss_security_group_id.value
  aoss_vpc_endpoint_id_raw  = data.aws_ssm_parameter.aoss_vpc_endpoint_id.value
  aoss_vpc_endpoint_id      = local.aoss_vpc_endpoint_id_raw == "none" ? null : local.aoss_vpc_endpoint_id_raw
  neptune_security_group_id = data.aws_ssm_parameter.neptune_security_group_id.value
  private_subnet_ids        = nonsensitive(split(",", data.aws_ssm_parameter.private_subnet_ids.value))
}

data "aws_ssm_parameter" "aoss_security_group_id" {
  name = "${local.ssm_prefix}/network/aoss-security-group-id"
}

data "aws_ssm_parameter" "aoss_vpc_endpoint_id" {
  name = "${local.ssm_prefix}/network/aoss-vpc-endpoint-id"
}

data "aws_ssm_parameter" "neptune_security_group_id" {
  name = "${local.ssm_prefix}/network/neptune-security-group-id"
}

data "aws_ssm_parameter" "private_subnet_ids" {
  name = "${local.ssm_prefix}/network/private-subnet-ids"
}
