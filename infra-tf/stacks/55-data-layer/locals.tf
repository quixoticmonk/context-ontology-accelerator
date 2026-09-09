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

  allowed_origin = var.ui_domain_name != null ? "https://${var.ui_domain_name}" : "*"

  # Network handoff
  vpc_id                   = data.aws_ssm_parameter.vpc_id.value
  private_subnet_ids       = nonsensitive(split(",", data.aws_ssm_parameter.private_subnet_ids.value))
  lambda_security_group_id = data.aws_ssm_parameter.lambda_security_group_id.value

  # Namespace handoff
  namespaces_table_name = data.aws_ssm_parameter.namespaces_table_name.value

  # Stack-30 handoff (metric + ontology Lambda ARNs)
  metric_api_fn_arn          = data.aws_ssm_parameter.metric_api_fn_arn.value
  ontology_engine_api_fn_arn = data.aws_ssm_parameter.ontology_api_fn_arn.value

  # Stack-60 handoff (serve AgentCore Runtime ARN)
  serve_runtime_arn = data.aws_ssm_parameter.serve_runtime_arn.value
}

data "aws_ssm_parameter" "vpc_id" { name = "${local.ssm_prefix}/network/vpc-id" }
data "aws_ssm_parameter" "private_subnet_ids" { name = "${local.ssm_prefix}/network/private-subnet-ids" }
data "aws_ssm_parameter" "lambda_security_group_id" { name = "${local.ssm_prefix}/network/lambda-security-group-id" }

data "aws_ssm_parameter" "namespaces_table_name" { name = "${local.ssm_prefix}/namespace/namespaces-table-name" }

data "aws_ssm_parameter" "metric_api_fn_arn" { name = "${local.ssm_prefix}/metric/api-fn-arn" }
data "aws_ssm_parameter" "ontology_api_fn_arn" { name = "${local.ssm_prefix}/ontology-engine/api-fn-arn" }

data "aws_ssm_parameter" "serve_runtime_arn" { name = "${local.ssm_prefix}/serve/runtime-arn" }
