# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  # ── Table names ────────────────────────────────────────────────────
  # Physical name = <name_prefix>-<logical name from TABLE_NAMES>.
  roles_table_name                  = "${var.name_prefix}-roles"
  resource_role_mappings_table_name = "${var.name_prefix}-resource-role-mappings"
  cache_invalidation_table_name     = "${var.name_prefix}-cache-invalidation"

  # ── Removal protection ─────────────────────────────────────────────
  # CDK uses RETAIN removal policy in prod and DESTROY elsewhere. The
  # closest Terraform analogue is deletion protection, enabled in prod.
  deletion_protection = var.environment == "prod"

  # ── Group -> role seed items ───────────────────────────────────────
  # Flatten claims_mappings into one item per (group, role) pair,
  # matching the CDK's nested SeedGroupMapping loop. Each item carries
  # the full ResourceRoleMappings record shape (base attributes + the
  # PrincipalIndex and NamespaceGrantsIndex GSI keys). Values mirror the
  # CDK exactly: resourceType "Platform", principalType "Group",
  # resourceId "GLOBAL".
  #
  # grantedAt is a static sentinel rather than the CDK's synth-time
  # ISO timestamp: timestamp() would force a perpetual diff on every
  # plan, and the field is informational (not a key).
  group_role_seed_items = {
    for pair in flatten([
      for m in var.claims_mappings : [
        for role_id in m.mapped_roles : {
          key     = "${m.group_value}-${role_id}"
          group   = m.group_value
          role_id = role_id
        }
      ]
    ]) : pair.key => pair
  }

  # ── Built-in role seed items ───────────────────────────────────────
  # Mirrors AuthnzStack.seedBuiltInRoles: 7 roles, each backed by a
  # Cedar policy file read at plan time via `file()`. Enabled only when
  # cedar_seed_path is set (matches the CDK's Paths.authorizationSeed
  # default, but overridable from the caller).
  #
  # PK derivation matches the CDK: "GLOBAL" for platform-scoped roles,
  # "NAMESPACE_TEMPLATE" for per-namespace roles. Same 7 roles + Cedar
  # filename pairs.
  builtin_roles = var.cedar_seed_path == null ? {} : {
    "platform-admin" = {
      name        = "Platform Admin"
      scope       = "GLOBAL"
      description = "Full access to all resources across all namespaces"
      file        = "global_admin.cedar"
    }
    "platform-viewer" = {
      name        = "Platform Viewer"
      scope       = "GLOBAL"
      description = "Read-only access across all namespaces"
      file        = "global_viewer.cedar"
    }
    "namespace-owner" = {
      name        = "Namespace Owner"
      scope       = "NAMESPACE"
      description = "Full control within a namespace"
      file        = "namespace_owner.cedar"
    }
    "data-steward" = {
      name        = "Data Steward"
      scope       = "NAMESPACE"
      description = "Manage data sources, ontologies, metrics, and documents within a namespace"
      file        = "namespace_data_steward.cedar"
    }
    "data-analyst" = {
      name        = "Data Analyst"
      scope       = "NAMESPACE"
      description = "Query and read access within a namespace"
      file        = "namespace_data_analyst.cedar"
    }
    "namespace-maintainer" = {
      name        = "Namespace Maintainer"
      scope       = "NAMESPACE"
      description = "Full control within a namespace"
      file        = "namespace_maintainer.cedar"
    }
    "default" = {
      name        = "Default"
      scope       = "GLOBAL"
      description = "Default policy applied to all authenticated users"
      file        = "default.cedar"
    }
  }
}
