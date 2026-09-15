# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Namespaces DynamoDB table + module-level data sources + SSM writes
# that don't depend on any specific downstream resource. IAM, DataZone,
# Lambdas, and the deletion pipeline live in dedicated files.

# AWS-managed KMS key for DynamoDB (kms_key_arn on server_side_encryption
# is required by CKV_AWS_119 even when using the aws/dynamodb key). Making
# it explicit vs. relying on the default so intent is auditable.
data "aws_kms_alias" "dynamodb" {
  name = "alias/aws/dynamodb"
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# ── Namespaces table ────────────────────────────────────────────────
# PK/SK strings + `name` GSI + TTL. Matches CDK DynamoDBTable(props):
#   partitionKey PK / sortKey SK
#   NameByIndex GSI: partitionKey name, projection ALL
#   timeToLiveAttribute ttl
resource "aws_dynamodb_table" "namespaces" {
  name         = local.namespaces_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "name"
    type = "S"
  }

  global_secondary_index {
    name            = "NameByIndex"
    hash_key        = "name"
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

# ── SSM writes ─────────────────────────────────────────────────────
# Mirror the CDK writes. Consumer services (metric-service, sources,
# ontology, api) read these at runtime via
# `ssm.StringParameter.valueForStringParameter`.

resource "aws_ssm_parameter" "namespaces_table_name" {
  name  = "${var.ssm_prefix}/namespace/namespaces-table-name"
  type  = "String"
  value = aws_dynamodb_table.namespaces.name
  tags  = local.tags
}

resource "aws_ssm_parameter" "domain_id" {
  name  = "${var.ssm_prefix}/smus/domain-id"
  type  = "String"
  value = aws_datazone_domain.this.id
  tags  = local.tags
}

resource "aws_ssm_parameter" "dz_project_access_role_arn" {
  name        = "${var.ssm_prefix}/smus/dz-project-access-role-arn"
  type        = "String"
  value       = aws_iam_role.dz_project_access.arn
  description = "New shared DataZone project access role ARN"
  tags        = local.tags
}

resource "aws_ssm_parameter" "login_role_arn" {
  name  = "${var.ssm_prefix}/smus/login-role-arn"
  type  = "String"
  value = aws_iam_role.login.arn
  tags  = local.tags
}

resource "aws_ssm_parameter" "namespace_api_fn_arn" {
  name  = "${var.ssm_prefix}/namespace/api-fn-arn"
  type  = "String"
  value = aws_lambda_function.namespace_api.arn
  tags  = local.tags
}

resource "aws_ssm_parameter" "roles_api_fn_arn" {
  name  = "${var.ssm_prefix}/namespace/roles-api-fn-arn"
  type  = "String"
  value = aws_lambda_function.roles_api.arn
  tags  = local.tags
}

resource "aws_ssm_parameter" "platform_roles_api_fn_arn" {
  name  = "${var.ssm_prefix}/namespace/platform-roles-api-fn-arn"
  type  = "String"
  value = aws_lambda_function.platform_roles_api.arn
  tags  = local.tags
}

resource "aws_ssm_parameter" "grants_api_fn_arn" {
  name  = "${var.ssm_prefix}/namespace/grants-api-fn-arn"
  type  = "String"
  value = aws_lambda_function.grants_api.arn
  tags  = local.tags
}
