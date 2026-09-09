# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "neptune_cluster_endpoint" {
  value = module.storage.neptune_cluster_endpoint
}

output "opensearch_collection_endpoint" {
  value = module.storage.opensearch_collection_endpoint
}

output "ontology_artifacts_bucket_name" {
  value = module.storage.ontology_artifacts_bucket_name
}

output "cognito_issuer_url" {
  value = module.auth_idp.issuer_url
}

output "user_pool_client_id" {
  value = module.auth_idp.user_pool_client_id
}

output "roles_table_name" {
  value = module.authnz.roles_table_name
}

output "guardrail_id" {
  value = module.guardrail.guardrail_id
}

output "edge_waf_web_acl_arn" {
  value = module.edge_waf.web_acl_arn
}
