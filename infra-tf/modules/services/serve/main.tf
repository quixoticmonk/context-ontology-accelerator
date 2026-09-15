# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Core resources: AgentCore Memory + Runtime + ECR + security group +
# session metadata table.

# AWS-managed KMS key for DynamoDB (kms_key_arn on server_side_encryption
# is required by CKV_AWS_119 even when using the aws/dynamodb key). Making
# it explicit vs. relying on the default so intent is auditable.
data "aws_kms_alias" "dynamodb" {
  name = "alias/aws/dynamodb"
}

# ═════════════════════════════════════════════════════════════════════
#  Security group (AgentCore runtime ENIs)
# ═════════════════════════════════════════════════════════════════════

resource "aws_security_group" "agentcore" {
  # checkov:skip=CKV2_AWS_5:Attached to the Context Manager AgentCore runtime via network_configuration.security_groups (see aws_bedrockagentcore_runtime.this below). checkov does not recognize the AgentCore attachment site.
  name        = "${var.name_prefix}-agentcore-sg"
  description = "AgentCore Runtime - Context Manager"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, {
    Name = "${var.name_prefix}-agentcore-sg"
  })
}

# HTTPS to VPC (VPC endpoints).
resource "aws_vpc_security_group_egress_rule" "agentcore_https_vpc" {
  security_group_id = aws_security_group.agentcore.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS to VPC endpoints"
  tags              = local.tags
}

# HTTPS to external services via NAT.
resource "aws_vpc_security_group_egress_rule" "agentcore_https_public" {
  security_group_id = aws_security_group.agentcore.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "HTTPS to external services via NAT"
  tags              = local.tags
}

# JDBC egress within VPC (Postgres/MySQL/MSSQL/Redshift).
resource "aws_vpc_security_group_egress_rule" "agentcore_jdbc_vpc" {
  for_each = toset(["5432", "3306", "1433", "5439"])

  security_group_id = aws_security_group.agentcore.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  description       = "JDBC ${each.value} within VPC"
  tags              = local.tags
}

# Neptune within VPC.
resource "aws_vpc_security_group_egress_rule" "agentcore_neptune" {
  security_group_id = aws_security_group.agentcore.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 8182
  to_port           = 8182
  description       = "Neptune Gremlin/SPARQL within VPC"
  tags              = local.tags
}

# VKG service within VPC.
resource "aws_vpc_security_group_egress_rule" "agentcore_vkg" {
  security_group_id = aws_security_group.agentcore.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
  description       = "VKG service within VPC"
  tags              = local.tags
}

# Allow AgentCore → AOSS VPC endpoint (SG-to-SG).
resource "aws_vpc_security_group_ingress_rule" "aoss_from_agentcore" {
  security_group_id            = var.aoss_security_group_id
  referenced_security_group_id = aws_security_group.agentcore.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS from AgentCore Runtime"
  tags                         = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  AgentCore Memory (session state)
# ═════════════════════════════════════════════════════════════════════

resource "aws_bedrockagentcore_memory" "session" {
  name                  = "${local.runtime_name}_memory"
  description           = "Conversation history for Playground multi-turn sessions"
  event_expiry_duration = 30

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  Session metadata DDB table
# ═════════════════════════════════════════════════════════════════════

resource "aws_dynamodb_table" "session_metadata" {
  name         = "${var.name_prefix}-session-metadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"
  range_key    = "sessionId"

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "sessionId"
    type = "S"
  }

  attribute {
    name = "lastActiveAt"
    type = "S"
  }

  attribute {
    name = "nsLastActiveAt"
    type = "S"
  }

  global_secondary_index {
    name            = "userId-lastActiveAt-index"
    hash_key        = "userId"
    range_key       = "lastActiveAt"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "userId-nsLastActiveAt-index"
    hash_key        = "userId"
    range_key       = "nsLastActiveAt"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = data.aws_kms_alias.dynamodb.target_key_arn
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  AgentCore Runtime
# ═════════════════════════════════════════════════════════════════════

resource "aws_bedrockagentcore_agent_runtime" "this" {
  agent_runtime_name = local.runtime_name
  role_arn           = aws_iam_role.runtime.arn
  description        = "Context Manager orchestration service"

  agent_runtime_artifact {
    container_configuration {
      container_uri = local.image_uri
    }
  }

  network_configuration {
    network_mode = "VPC"

    network_mode_config {
      subnets         = local.runtime_subnet_ids
      security_groups = [aws_security_group.agentcore.id]
    }
  }

  authorizer_configuration {
    custom_jwt_authorizer {
      discovery_url    = "${var.issuer_url}/.well-known/openid-configuration"
      allowed_audience = [var.userpool_client_id, var.mcp_client_id]
    }
  }

  request_header_configuration {
    request_header_allowlist = ["Authorization"]
  }

  environment_variables = local.runtime_env

  tags = local.tags
}
