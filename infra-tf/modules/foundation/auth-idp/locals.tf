# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  # ── Branch selection ───────────────────────────────────────────────
  # COGNITO and SAML both provision the full Cognito stack; OIDC skips it
  # entirely and only writes SSM parameters from var.oidc_settings.
  cognito_enabled = var.idp_type != "OIDC"

  # ── Admin group ────────────────────────────────────────────────────
  # Mirrors the CDK: the initial admin user is placed in an "Admin" group
  # and DEFAULT_GROUP_CLAIM ("cognito:groups") carries membership.
  admin_group = "Admin"
  group_claim = "cognito:groups"

  # ── Web app client callback URLs ───────────────────────────────────
  # Cognito requires at least one callback URL. When a custom UI domain is
  # supplied, merge its authenticate path in alongside the configured URLs.
  custom_domain_callback_url = var.custom_domain_ui_domain_name != null ? "https://${var.custom_domain_ui_domain_name}/authenticate/" : null
  callback_urls = distinct(concat(
    var.callback_urls,
    local.custom_domain_callback_url != null ? [local.custom_domain_callback_url] : [],
  ))

  # ── Federated identity provider keys ───────────────────────────────
  # Cognito is always a supported IdP; each SAML/OIDC provider name is
  # appended so the user pool clients advertise them.
  saml_provider_names = [for p in var.saml_providers : p.name]
  oidc_provider_names = [for p in var.oidc_providers : p.name]
  supported_identity_providers = concat(
    ["COGNITO"],
    local.saml_provider_names,
    local.oidc_provider_names,
  )

  # ── SSM values (branch-dependent) ──────────────────────────────────
  # Cognito modes derive issuer/client IDs from the created resources;
  # OIDC mode passes external settings straight through.
  issuer_url = local.cognito_enabled ? (
    "https://cognito-idp.${data.aws_region.current.region}.amazonaws.com/${aws_cognito_user_pool.this[0].id}"
  ) : var.oidc_settings.issuer_url

  userpool_client_id = local.cognito_enabled ? aws_cognito_user_pool_client.userpool[0].id : var.oidc_settings.client_id

  # For OIDC the external IdP uses the same client for web and MCP flows.
  mcp_client_id = local.cognito_enabled ? aws_cognito_user_pool_client.mcp[0].id : var.oidc_settings.client_id

  ssm_group_token_name = local.cognito_enabled ? local.group_claim : var.oidc_settings.group_claim
}
