# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Stack 50 — API Gateway + Web (CloudFront + S3). Depends on 20-namespace,
# 30-services, and 40-sources for Lambda ARNs.

locals {
  api_path_handlers = {
    "/namespaces"                      = local.namespace_api_fn_arn
    "/namespaces/{namespaceId}"        = local.namespace_api_fn_arn
    "/namespaces/{namespaceId}/status" = local.namespace_api_fn_arn

    "/namespaces/{namespaceId}/sources"                                                           = local.sources_fn_arn
    "/namespaces/{namespaceId}/sources/{sourceId}"                                                = local.sources_fn_arn
    "/namespaces/{namespaceId}/sources/{sourceId}/rescan"                                         = local.sources_fn_arn
    "/namespaces/{namespaceId}/sources/{sourceId}/tables"                                         = local.sources_fn_arn
    "/namespaces/{namespaceId}/sources/{sourceId}/tables/{tableId}"                               = local.sources_fn_arn
    "/namespaces/{namespaceId}/sources/{sourceId}/approve"                                        = local.sources_fn_arn
    "/namespaces/{namespaceId}/sources/{sourceId}/reject"                                         = local.sources_fn_arn
    "/namespaces/{namespaceId}/sources/{sourceId}/tables/{tableId}/review"                        = local.sources_fn_arn
    "/namespaces/{namespaceId}/sources/{sourceId}/tables/{tableId}/metadata"                      = local.sources_fn_arn
    "/namespaces/{namespaceId}/sources/{sourceId}/tables/{tableId}/keys"                          = local.sources_fn_arn
    "/namespaces/{namespaceId}/sources/{sourceId}/tables/{tableId}/columns/{columnName}/review"   = local.sources_fn_arn
    "/namespaces/{namespaceId}/sources/{sourceId}/tables/{tableId}/columns/{columnName}/metadata" = local.sources_fn_arn
    "/namespaces/{namespaceId}/sources/{sourceId}/scan/{jobId}"                                   = local.sources_fn_arn
    "/namespaces/{namespaceId}/sources/{sourceId}/metadata"                                       = local.sources_fn_arn
    "/namespaces/{namespaceId}/sources/upload-urls"                                               = local.sources_fn_arn

    "/roles"                                     = local.namespace_platform_fn_arn
    "/namespaces/{namespaceId}/roles"            = local.namespace_roles_fn_arn
    "/namespaces/{namespaceId}/roles/{roleId}"   = local.namespace_roles_fn_arn
    "/namespaces/{namespaceId}/grants"           = local.namespace_grants_fn_arn
    "/namespaces/{namespaceId}/grants/{grantId}" = local.namespace_grants_fn_arn
    "/principals/{principalId}/grants"           = local.namespace_grants_fn_arn
    "/grants"                                    = local.namespace_grants_fn_arn
    "/grants/{grantId}"                          = local.namespace_grants_fn_arn

    "/namespaces/{namespaceId}/metrics"               = local.metric_fn_arn
    "/namespaces/{namespaceId}/metrics/{name}"        = local.metric_fn_arn
    "/namespaces/{namespaceId}/metrics/validate"      = local.metric_fn_arn
    "/namespaces/{namespaceId}/bulk-delete-metrics"   = local.metric_fn_arn
    "/namespaces/{namespaceId}/import-osi"            = local.metric_fn_arn
    "/namespaces/{namespaceId}/import-osi/upload-url" = local.metric_fn_arn
    "/namespaces/{namespaceId}/import-jobs/{jobId}"   = local.metric_fn_arn
    "/namespaces/{namespaceId}/export-osi"            = local.metric_fn_arn

    "/namespaces/{namespaceId}/induce"                                                = local.ontology_fn_arn
    "/namespaces/{namespaceId}/induce/jobs"                                           = local.ontology_fn_arn
    "/namespaces/{namespaceId}/induce/jobs/{jobId}"                                   = local.ontology_fn_arn
    "/namespaces/{namespaceId}/induce/datasources"                                    = local.ontology_fn_arn
    "/namespaces/{namespaceId}/induce/datasources/induced"                            = local.ontology_fn_arn
    "/namespaces/{namespaceId}/proposals"                                             = local.ontology_fn_arn
    "/namespaces/{namespaceId}/proposals/{proposalId}"                                = local.ontology_fn_arn
    "/namespaces/{namespaceId}/proposals/{proposalId}/accept"                         = local.ontology_fn_arn
    "/namespaces/{namespaceId}/proposals/{proposalId}/cancel"                         = local.ontology_fn_arn
    "/namespaces/{namespaceId}/proposals/{proposalId}/infer-constraints"              = local.ontology_fn_arn
    "/namespaces/{namespaceId}/proposals/{proposalId}/infer-constraints/jobs/{jobId}" = local.ontology_fn_arn
    "/namespaces/{namespaceId}/proposals/{proposalId}/compile-constraints"            = local.ontology_fn_arn
    "/namespaces/{namespaceId}/proposals/{proposalId}/validate"                       = local.ontology_fn_arn
    "/namespaces/{namespaceId}/proposals/{proposalId}/validate/jobs/{jobId}"          = local.ontology_fn_arn
    "/namespaces/{namespaceId}/proposals/{proposalId}/repair-datatypes"               = local.ontology_fn_arn
    "/namespaces/{namespaceId}/proposals/{proposalId}/upload-url"                     = local.ontology_fn_arn
    "/namespaces/{namespaceId}/proposals/update"                                      = local.ontology_fn_arn
    "/namespaces/{namespaceId}/proposals/reject"                                      = local.ontology_fn_arn
    "/namespaces/{namespaceId}/ontology/foundational"                                 = local.ontology_fn_arn
    "/namespaces/{namespaceId}/ontology/foundational/{key}/load"                      = local.ontology_fn_arn
    "/namespaces/{namespaceId}/graph/search"                                          = local.ontology_fn_arn
    "/namespaces/{namespaceId}/graph/ontology-overview"                               = local.ontology_fn_arn
    "/namespaces/{namespaceId}/graph/class"                                           = local.ontology_fn_arn
    "/namespaces/{namespaceId}/graph/object-property"                                 = local.ontology_fn_arn
    "/namespaces/{namespaceId}/graph/datatype-property"                               = local.ontology_fn_arn
    "/namespaces/{namespaceId}/ontologies"                                            = local.ontology_fn_arn
    "/namespaces/{namespaceId}/ontologies/{ontologyId}"                               = local.ontology_fn_arn
    "/namespaces/{namespaceId}/ontologies/{ontologyId}/download"                      = local.ontology_fn_arn
    "/namespaces/{namespaceId}/ontologies/upload-url"                                 = local.ontology_fn_arn
    "/namespaces/{namespaceId}/ontologies/{ontologyId}/fetch"                         = local.ontology_fn_arn
    "/namespaces/{namespaceId}/ontologies/{ontologyId}/ingest-from-s3"                = local.ontology_fn_arn
    "/namespaces/{namespaceId}/ontologies/{ontologyId}/ingest-status/{jobId}"         = local.ontology_fn_arn
    "/namespaces/{namespaceId}/embeddings"                                            = local.ontology_fn_arn
    "/namespaces/{namespaceId}/embeddings/batch"                                      = local.ontology_fn_arn
    "/namespaces/{namespaceId}/embeddings/search"                                     = local.ontology_fn_arn
    "/namespaces/{namespaceId}/embeddings/by-entity/{entityUri}"                      = local.ontology_fn_arn
    "/namespaces/{namespaceId}/embeddings/by-ontology/{ontologyId}"                   = local.ontology_fn_arn
    "/namespaces/{namespaceId}/validate"                                              = local.ontology_fn_arn
    "/namespaces/{namespaceId}/validate/jobs"                                         = local.ontology_fn_arn
    "/namespaces/{namespaceId}/validate/jobs/{jobId}"                                 = local.ontology_fn_arn
    "/system-health"                                                                  = local.ontology_fn_arn

    "/namespaces/{namespaceId}/query"          = local.data_layer_fn_arn
    "/namespaces/{namespaceId}/translate"      = local.data_layer_fn_arn
    "/namespaces/{namespaceId}/kb/search"      = local.data_layer_fn_arn
    "/namespaces/{namespaceId}/graph/traverse" = local.data_layer_fn_arn
    "/namespaces/{namespaceId}/schema"         = local.data_layer_fn_arn
  }
}

module "api" {
  source = "../../modules/services/api"

  allowed_origin                = local.allowed_origin
  cache_invalidation_table_arn  = local.cache_invalidation_table_arn
  cache_invalidation_table_name = local.cache_invalidation_table_name
  control_plane_zip_path        = "${path.root}/../../artifacts/lambdas/control-plane.zip"
  custom_domain = local.custom_domain != null ? {
    api_domain_name     = var.api_domain_name
    api_certificate_arn = var.api_certificate_arn
    hosted_zone_id      = var.hosted_zone_id
  } : null
  lambda_security_group_id                = local.lambda_security_group_id
  merged_spec_path                        = "${path.root}/../../artifacts/openapi/merged.json"
  name_prefix                             = local.name_prefix
  namespaces_table_arn                    = local.namespaces_table_arn
  path_handlers                           = local.api_path_handlers
  private_subnet_ids                      = local.private_subnet_ids
  region                                  = var.region
  resource_role_mappings_table_arn        = local.resource_role_mappings_table_arn
  resource_role_mappings_table_name       = local.resource_role_mappings_table_name
  resource_role_mappings_table_stream_arn = local.resource_role_mappings_table_stream_arn
  roles_table_arn                         = local.roles_table_arn
  roles_table_name                        = local.roles_table_name
  roles_table_stream_arn                  = local.roles_table_stream_arn
  ssm_prefix                              = local.ssm_prefix
  vpc_id                                  = local.vpc_id
  api_web_acl_arn                         = var.api_web_acl_arn
}

module "web" {
  source    = "../../modules/foundation/web"
  providers = { aws = aws, aws.us_east_1 = aws.us_east_1 }

  api_endpoint    = module.api.api_endpoint
  api_rest_api_id = module.api.api_id
  api_stage_name  = module.api.stage_name
  auto_web_acl_param = var.cloudfront_web_acl_arn == null ? {
    name   = "${local.ssm_prefix}/edge/cloudfront-web-acl-arn"
    region = "us-east-1"
  } : null
  custom_domain = local.custom_domain != null ? {
    ui_domain_name     = var.ui_domain_name
    ui_certificate_arn = var.ui_certificate_arn
    hosted_zone_id     = var.hosted_zone_id
  } : null
  is_cognito_mode      = var.idp_type != "OIDC"
  name_prefix          = local.name_prefix
  serve_runtime_arn    = local.serve_runtime_arn
  ssm_prefix           = local.ssm_prefix
  web_acl_arn          = var.cloudfront_web_acl_arn
  website_content_path = "${path.root}/../../../packages/web-app/dist"

  # Wire the Cognito callback patch — CloudFront domain isn't known
  # until this stack applies, so patching the pool client is deferred
  # here (via a Lambda invoked by the aws_lambda_invoke action).
  user_pool_id                    = var.idp_type != "OIDC" ? nonsensitive(data.aws_ssm_parameter.user_pool_id[0].value) : ""
  userpool_client_id              = var.idp_type != "OIDC" ? nonsensitive(data.aws_ssm_parameter.userpool_client_id[0].value) : ""
  cognito_callback_patch_zip_path = "${path.root}/../../artifacts/lambdas/cognito-callback-patch.zip"
  cognito_hosted_ui_origin        = var.idp_type != "OIDC" ? "https://${nonsensitive(data.aws_ssm_parameter.userpool_domain[0].value)}.auth.${var.region}.amazoncognito.com" : ""
  api_cors_patch_zip_path         = "${path.root}/../../artifacts/lambdas/api-cors-patch.zip"
}

# ── Stack-added SSM writes for observability ─────────────────────────

resource "aws_ssm_parameter" "api_id" {
  name  = "${local.ssm_prefix}/api/rest-api-id"
  type  = "String"
  value = module.api.api_id
}

resource "aws_ssm_parameter" "cache_invalidation_dlq_arn" {
  name  = "${local.ssm_prefix}/api/cache-invalidation-dlq-arn"
  type  = "String"
  value = module.api.cache_invalidation_dlq_arn
}
