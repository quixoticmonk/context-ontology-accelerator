# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Stack 20 — Namespace (DataZone/SMUS domain + deletion pipeline).
# Consumes 00-network + 10-foundation via SSM.

module "namespace" {
  source = "../../modules/services/namespace"

  allowed_origin                    = local.allowed_origin
  cache_invalidation_table_name     = local.cache_invalidation_table_name
  cloud_map_namespace_id            = local.cloud_map_namespace_id
  control_plane_zip_path            = "${path.root}/../../artifacts/lambdas/control-plane.zip"
  lambda_security_group_id          = local.lambda_security_group_id
  name_prefix                       = local.name_prefix
  ontology_bucket_name              = local.ontology_bucket_name
  ontology_engine_endpoint          = null # Wired by 30-services indirection at runtime; namespace does not need it at deploy.
  opensearch_collection_name        = local.opensearch_collection_name
  opensearch_endpoint               = local.opensearch_endpoint
  private_subnet_ids                = local.private_subnet_ids
  region                            = var.region
  resource_prefix                   = var.resource_prefix
  resource_role_mappings_table_arn  = local.resource_role_mappings_table_arn
  resource_role_mappings_table_name = local.resource_role_mappings_table_name
  roles_table_arn                   = local.roles_table_arn
  roles_table_name                  = local.roles_table_name
  smus_admin_principal_arns         = var.smus_admin_principal_arns
  smus_require_mfa                  = var.smus_require_mfa
  ssm_prefix                        = local.ssm_prefix
  vkg_cluster_arn                   = null # 30-services provides it; namespace's use is optional.
  vpc_id                            = local.vpc_id
}

# ── Stack-added SSM writes for downstream stacks ─────────────────────
# Namespace module writes namespaces_table_name, domain_id, project
# access role, login role, and API fn ARNs. Add table ARN for stacks
# that need it (30-services, 40-sources, 50-agentcore).

resource "aws_ssm_parameter" "namespaces_table_arn" {
  name  = "${local.ssm_prefix}/namespace/namespaces-table-arn"
  type  = "String"
  value = module.namespace.namespaces_table_arn
}
