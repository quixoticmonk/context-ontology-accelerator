# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "issuer_url" {
  description = "OIDC issuer URL. Cognito modes derive it from the user pool; OIDC mode passes through oidc_settings.issuer_url."
  value       = local.issuer_url
}

output "mcp_client_id" {
  description = "MCP/CLI client ID. Null-safe: Cognito modes give the MCP client ID, OIDC mode reuses oidc_settings.client_id."
  value       = local.mcp_client_id
}

output "user_pool_arn" {
  description = "Cognito user pool ARN. Null in OIDC mode (no user pool is provisioned)."
  value       = local.cognito_enabled ? aws_cognito_user_pool.this[0].arn : null
}

output "user_pool_client_id" {
  description = "Web app user pool client ID. Cognito modes give the userpool client ID; OIDC mode gives oidc_settings.client_id."
  value       = local.userpool_client_id
}

output "user_pool_domain" {
  description = "Cognito hosted UI domain prefix. Null in OIDC mode."
  value       = local.cognito_enabled ? aws_cognito_user_pool_domain.this[0].domain : null
}

output "user_pool_id" {
  description = "Cognito user pool ID. Null in OIDC mode."
  value       = local.cognito_enabled ? aws_cognito_user_pool.this[0].id : null
}
