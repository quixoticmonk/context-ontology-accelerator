# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# MCP Server: thin protocol adapter on AgentCore Runtime.
#
# Discovery tools (list_metrics, describe_schema) invoke backend Lambdas
# directly; execution tools (query, translate, rag, graph) forward to the
# Context Manager via the AgentCore invocations API. The server does NOT run
# the orchestrator in-process. IAM lives in iam.tf; this file holds the
# security group, ECR repo, the AgentCore Runtime, and the SSM writes.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Per-subnet AZ lookup — used to filter placement to AgentCore-supported AZs
# (see local.runtime_subnet_ids). for_each over the passed subnet IDs so the
# lookup keys line up with the ID list.
data "aws_subnet" "private" {
  for_each = toset(var.private_subnet_ids)
  id       = each.value
}

# ════════════════════════════════════════════════════════════════════
#  Security group (minimal: HTTPS egress only)
# ════════════════════════════════════════════════════════════════════
resource "aws_security_group" "mcp" {
  # checkov:skip=CKV2_AWS_5:Attached to the MCP AgentCore runtime via network_configuration.security_groups (see aws_bedrockagentcore_runtime.mcp below). checkov does not recognize the AgentCore attachment site.
  name        = "${local.ecr_repo_name}-sg"
  description = "AgentCore Runtime - MCP Server (thin proxy)"
  vpc_id      = var.vpc_id

  tags = local.tags
}

# HTTPS to VPC endpoints (AgentCore invocations reachable in-VPC).
resource "aws_vpc_security_group_egress_rule" "https_vpc" {
  security_group_id = aws_security_group.mcp.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS to VPC endpoints (AgentCore)"

  tags = local.tags
}

# HTTPS to the AgentCore public endpoint (invocations API via NAT).
resource "aws_vpc_security_group_egress_rule" "https_public" {
  security_group_id = aws_security_group.mcp.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS to AgentCore invocations API"

  tags = local.tags
}

# ════════════════════════════════════════════════════════════════════
#  AgentCore Runtime (MCP protocol)
# ════════════════════════════════════════════════════════════════════
resource "aws_bedrockagentcore_agent_runtime" "this" {
  agent_runtime_name = local.runtime_name
  role_arn           = aws_iam_role.mcp_runtime.arn
  description        = "MCP Server - protocol adapter with PKCE auth, forwards execution to Context Manager"

  environment_variables = local.environment_variables

  agent_runtime_artifact {
    container_configuration {
      container_uri = local.image_uri
    }
  }

  protocol_configuration {
    server_protocol = "MCP"
  }

  # VPC placement: network_mode is a top-level attribute; subnets +
  # security_groups live in the nested network_mode_config block (verified
  # against the aws v6.63 provider schema).
  network_configuration {
    network_mode = "VPC"

    network_mode_config {
      subnets         = local.runtime_subnet_ids
      security_groups = [aws_security_group.mcp.id]
    }
  }

  # allowed_clients omitted: AgentCore uses AND semantics on allowed_clients,
  # and ID tokens don't carry client_id. Use the aud claim via
  # allowed_audience (present on both web app and MCP CLI tokens).
  authorizer_configuration {
    custom_jwt_authorizer {
      discovery_url    = "${var.issuer_url}/.well-known/openid-configuration"
      allowed_audience = [var.userpool_client_id, var.mcp_client_id]
    }
  }

  # Propagate the caller's JWT to the runtime so claims.py can verify it.
  request_header_configuration {
    request_header_allowlist = ["Authorization"]
  }

  tags = local.tags
}

# ════════════════════════════════════════════════════════════════════
#  SSM parameters (match CDK writes)
# ════════════════════════════════════════════════════════════════════
resource "aws_ssm_parameter" "runtime_arn" {
  name        = "${var.ssm_prefix}/mcp/runtime-arn"
  type        = "String"
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn
  description = "AgentCore Runtime ARN for the MCP Server"

  tags = local.tags
}

resource "aws_ssm_parameter" "runtime_role_arn" {
  name        = "${var.ssm_prefix}/mcp/runtime-role-arn"
  type        = "String"
  value       = aws_iam_role.mcp_runtime.arn
  description = "MCP Runtime IAM role ARN"

  tags = local.tags
}
