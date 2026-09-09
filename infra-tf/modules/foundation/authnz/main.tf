# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# AuthNZ subsystem DynamoDB tables. Ported from the CDK AuthnzStack.
#
# Tables:
#   - roles                  — namespace-scoped and global role definitions
#   - resource-role-mappings — principal <-> resource <-> role grants with
#                              PrincipalIndex and NamespaceGrantsIndex GSIs
#   - cache-invalidation     — version counter for auth cache busting
#
# All tables use PAY_PER_REQUEST billing, AWS-managed encryption, and PITR.
# Streams (NEW_AND_OLD_IMAGES) are enabled on roles and resource-role-mappings
# to drive cache invalidation; cache-invalidation itself has no stream
# (matches the CDK).

# ── Roles ──────────────────────────────────────────────────────────
resource "aws_dynamodb_table" "roles" {
  name             = local.roles_table_name
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "PK"
  range_key        = "SK"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  deletion_protection_enabled = local.deletion_protection

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Component = var.component
  }
}

# ── ResourceRoleMappings ───────────────────────────────────────────
resource "aws_dynamodb_table" "resource_role_mappings" {
  name             = local.resource_role_mappings_table_name
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "PK"
  range_key        = "SK"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  deletion_protection_enabled = local.deletion_protection

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "principalKey"
    type = "S"
  }

  attribute {
    name = "resourceRoleKey"
    type = "S"
  }

  attribute {
    name = "namespaceKey"
    type = "S"
  }

  attribute {
    name = "principalRoleKey"
    type = "S"
  }

  global_secondary_index {
    name            = "PrincipalIndex"
    hash_key        = "principalKey"
    range_key       = "resourceRoleKey"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "NamespaceGrantsIndex"
    hash_key        = "namespaceKey"
    range_key       = "principalRoleKey"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Component = var.component
  }
}

# ── CacheInvalidation ──────────────────────────────────────────────
# No stream (matches the CDK — only roles and resource-role-mappings
# stream to the cache-invalidation Lambda).
resource "aws_dynamodb_table" "cache_invalidation" {
  name         = local.cache_invalidation_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  deletion_protection_enabled = local.deletion_protection

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Component = var.component
  }
}

# ── Group -> role seed items ───────────────────────────────────────
# One item per (group, role) pair from claims_mappings, written into
# resource-role-mappings. Item shape and key derivations mirror the
# CDK SeedGroupMapping custom resources exactly (resourceType
# "Platform", resourceId "GLOBAL", principalType "Group").
#
# lifecycle.ignore_changes on item lets the application mutate these
# rows post-seed (e.g. re-grant metadata) without Terraform reverting
# them on the next apply.
resource "aws_dynamodb_table_item" "group_role_mapping" {
  for_each = local.group_role_seed_items

  table_name = aws_dynamodb_table.resource_role_mappings.name
  hash_key   = aws_dynamodb_table.resource_role_mappings.hash_key
  range_key  = aws_dynamodb_table.resource_role_mappings.range_key

  item = jsonencode({
    PK               = { S = "Platform::GLOBAL#Group::${each.value.group}" }
    SK               = { S = "ROLE#${each.value.role_id}" }
    resourceType     = { S = "Platform" }
    resourceId       = { S = "GLOBAL" }
    principalType    = { S = "Group" }
    principalId      = { S = each.value.group }
    role             = { S = each.value.role_id }
    principalKey     = { S = "Group::${each.value.group}" }
    resourceRoleKey  = { S = "Platform::GLOBAL#ROLE#${each.value.role_id}" }
    namespaceKey     = { S = "NS#GLOBAL" }
    principalRoleKey = { S = "Group::${each.value.group}#ROLE#${each.value.role_id}" }
    grantedBy        = { S = "system" }
    grantedAt        = { S = "1970-01-01T00:00:00Z" }
  })

  lifecycle {
    ignore_changes = [item]
  }
}

# ── Built-in role seed items ───────────────────────────────────────
# Mirrors CDK AuthnzStack.seedBuiltInRoles(): reads a `.cedar` policy
# file per built-in role from `var.cedar_seed_path` at plan time and
# writes the role record into the roles table.
#
# PK = "GLOBAL" for platform-scoped roles, "NAMESPACE_TEMPLATE" for
# per-namespace roles (matches the CDK's `scope === "GLOBAL"` check).
#
# createdAt/updatedAt are static sentinels for the same reason as
# grantedAt above — the CDK's synth-time timestamps would produce a
# perpetual plan diff.
#
# lifecycle.ignore_changes on item so operator/UI edits to role
# metadata (name/description changes) survive re-applies. When the
# Cedar policy file itself changes, remove the item from state
# (`terraform state rm`) and re-apply to force a re-seed.
resource "aws_dynamodb_table_item" "builtin_role" {
  for_each = local.builtin_roles

  table_name = aws_dynamodb_table.roles.name
  hash_key   = aws_dynamodb_table.roles.hash_key
  range_key  = aws_dynamodb_table.roles.range_key

  item = jsonencode({
    PK          = { S = each.value.scope == "GLOBAL" ? "GLOBAL" : "NAMESPACE_TEMPLATE" }
    SK          = { S = "ROLE#${each.key}" }
    name        = { S = each.value.name }
    description = { S = each.value.description }
    isBuiltIn   = { BOOL = true }
    cedarPolicy = { S = file("${var.cedar_seed_path}/${each.value.file}") }
    scope       = { S = each.value.scope }
    createdAt   = { S = "1970-01-01T00:00:00Z" }
    updatedAt   = { S = "1970-01-01T00:00:00Z" }
  })

  lifecycle {
    ignore_changes = [item]
  }
}

# ── SSM: table metadata for runtime consumers ──────────────────────
# Runtime services (authorizer, cache-invalidation Lambda) read the
# AuthNZ table names from SSM under the shared ssm_prefix, mirroring
# how the network module publishes VPC metadata.
resource "aws_ssm_parameter" "roles_table_name" {
  name  = "${var.ssm_prefix}/authnz/roles-table-name"
  type  = "String"
  value = aws_dynamodb_table.roles.name

  tags = {
    Component = var.component
  }
}

resource "aws_ssm_parameter" "resource_role_mappings_table_name" {
  name  = "${var.ssm_prefix}/authnz/resource-role-mappings-table-name"
  type  = "String"
  value = aws_dynamodb_table.resource_role_mappings.name

  tags = {
    Component = var.component
  }
}

resource "aws_ssm_parameter" "cache_invalidation_table_name" {
  name  = "${var.ssm_prefix}/authnz/cache-invalidation-table-name"
  type  = "String"
  value = aws_dynamodb_table.cache_invalidation.name

  tags = {
    Component = var.component
  }
}
