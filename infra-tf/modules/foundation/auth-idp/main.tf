# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Identity provider authentication. Three deployment modes:
#   COGNITO → Cognito user pool + clients + optional federation (default)
#   SAML    → Cognito user pool + clients + SAML provider(s)
#   OIDC    → no Cognito; external issuer/client details written to SSM
#
# Every Cognito resource is gated on `local.cognito_enabled` so the OIDC
# branch provisions nothing but SSM parameters.

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# ── User pool ──────────────────────────────────────────────────────
# selfSignUp disabled (admin-create-only), email sign-in alias, strong
# password policy, ESSENTIALS feature plan. Custom attributes come from
# var.cognito_custom_attributes. Destroyed with the stack (greenfield).
resource "aws_cognito_user_pool" "this" {
  count = local.cognito_enabled ? 1 : 0

  name                     = "${var.name_prefix}-user-pool"
  deletion_protection      = "INACTIVE"
  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  user_pool_tier = "ESSENTIALS"

  dynamic "schema" {
    for_each = var.cognito_custom_attributes

    content {
      name                     = schema.key
      attribute_data_type      = schema.value == "number" ? "Number" : "String"
      developer_only_attribute = false
      mutable                  = true
      required                 = false
    }
  }

  tags = {
    Component = var.component
  }
}

# ── Admin group ────────────────────────────────────────────────────
# The initial admin user is placed here; DEFAULT_GROUP_CLAIM carries it.
resource "aws_cognito_user_group" "admin" {
  count = local.cognito_enabled ? 1 : 0

  name         = local.admin_group
  user_pool_id = aws_cognito_user_pool.this[0].id
  description  = "Initial admin group"
}

# ── Hosted UI domain ───────────────────────────────────────────────
# Cognito prefix domain (not a custom domain), suffixed with the account
# ID to keep the globally-unique prefix collision-resistant.
resource "aws_cognito_user_pool_domain" "this" {
  count = local.cognito_enabled ? 1 : 0

  domain       = "${var.name_prefix}-auth-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.this[0].id
}

# ── SAML identity providers ────────────────────────────────────────
resource "aws_cognito_identity_provider" "saml" {
  for_each = local.cognito_enabled ? { for p in var.saml_providers : p.name => p } : {}

  user_pool_id  = aws_cognito_user_pool.this[0].id
  provider_name = each.key
  provider_type = "SAML"

  provider_details = merge(
    each.value.metadata_url != null ? { MetadataURL = each.value.metadata_url } : {},
    each.value.metadata_content != null ? { MetadataFile = each.value.metadata_content } : {},
  )
}

# ── OIDC identity providers (federated through Cognito) ────────────
resource "aws_cognito_identity_provider" "oidc" {
  # nonsensitive() strips the sensitivity marker from the outer list so
  # the map keys (provider names) are usable as for_each keys.
  # Individual client_secret values are still handled as sensitive by
  # aws_cognito_identity_provider itself.
  for_each = local.cognito_enabled ? { for p in nonsensitive(var.oidc_providers) : p.name => p } : {}

  user_pool_id  = aws_cognito_user_pool.this[0].id
  provider_name = each.key
  provider_type = "OIDC"

  provider_details = {
    client_id                 = each.value.client_id
    client_secret             = each.value.client_secret
    oidc_issuer               = each.value.issuer_url
    authorize_scopes          = join(" ", each.value.scopes)
    attributes_request_method = "GET"
  }
}

# ── Web app user pool client ───────────────────────────────────────
# SPA public client (no secret). Authorization Code grant, OIDC scopes,
# callback/logout URLs, SRP auth. Refresh token validity configurable.
resource "aws_cognito_user_pool_client" "userpool" {
  count = local.cognito_enabled ? 1 : 0

  name         = "${var.name_prefix}-client"
  user_pool_id = aws_cognito_user_pool.this[0].id

  generate_secret               = false
  explicit_auth_flows           = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  prevent_user_existence_errors = "ENABLED"

  supported_identity_providers = local.supported_identity_providers

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  callback_urls                        = local.callback_urls
  logout_urls                          = var.logout_urls

  refresh_token_validity = var.refresh_token_validity_hours

  token_validity_units {
    refresh_token = "hours"
  }

  depends_on = [
    aws_cognito_identity_provider.saml,
    aws_cognito_identity_provider.oidc,
  ]

  # The CloudFront domain isn't known until stack 60-api-edge applies, so
  # stack 60's web module invokes `cognito-callback-patch` Lambda to add
  # `https://<cf-domain>/authenticate/` and `https://<cf-domain>/` to
  # these two allowlists AFTER-the-fact. Every subsequent `terraform
  # apply` on stack 10 would revert those additions if TF still owned
  # the fields — ignore them so the Lambda's patches survive.
  lifecycle {
    ignore_changes = [callback_urls, logout_urls]
  }
}

# ── MCP/CLI public client ──────────────────────────────────────────
# PKCE-style public client for IDE integrations. Localhost redirect,
# long-lived tokens (24h access/id, 30d refresh) so IDE sessions don't
# reconnect hourly.
resource "aws_cognito_user_pool_client" "mcp" {
  count = local.cognito_enabled ? 1 : 0

  name         = "${var.name_prefix}-mcp-client"
  user_pool_id = aws_cognito_user_pool.this[0].id

  generate_secret               = false
  explicit_auth_flows           = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  prevent_user_existence_errors = "ENABLED"

  supported_identity_providers = local.supported_identity_providers

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  callback_urls                        = ["http://localhost:9876/oauth/callback"]
  logout_urls                          = ["http://localhost:9876/"]

  access_token_validity  = 24
  id_token_validity      = 24
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  depends_on = [
    aws_cognito_identity_provider.saml,
    aws_cognito_identity_provider.oidc,
  ]
}

# ── Initial admin user ─────────────────────────────────────────────
# Replaces the CDK custom-resource admin creator with a native user +
# generated temporary password. Cognito emails the temporary password
# (no message_action suppression), matching the CDK's EMAIL delivery.
resource "random_password" "admin_temp" {
  count = local.cognito_enabled ? 1 : 0

  length           = 16
  lower            = true
  upper            = true
  numeric          = true
  special          = true
  override_special = "!@#$%^&*()-_=+"

  # Only regenerate when the admin email changes (an intentional rotation),
  # not on every apply.
  keepers = {
    initial_admin_email = var.initial_admin_email
  }
}

resource "aws_cognito_user" "admin" {
  count = local.cognito_enabled ? 1 : 0

  user_pool_id       = aws_cognito_user_pool.this[0].id
  username           = var.initial_admin_email
  temporary_password = random_password.admin_temp[0].result

  attributes = {
    email          = var.initial_admin_email
    email_verified = "true"
  }
}

resource "aws_cognito_user_in_group" "admin" {
  count = local.cognito_enabled ? 1 : 0

  user_pool_id = aws_cognito_user_pool.this[0].id
  group_name   = aws_cognito_user_group.admin[0].name
  username     = aws_cognito_user.admin[0].username
}

# ── SSM parameters ─────────────────────────────────────────────────
# Written in every mode; values differ by branch (see locals.tf). The
# user-pool-id parameter is Cognito-only.
resource "aws_ssm_parameter" "user_pool_id" {
  count = local.cognito_enabled ? 1 : 0

  name  = "${var.ssm_prefix}/userpool-id"
  type  = "String"
  value = aws_cognito_user_pool.this[0].id

  tags = {
    Component = var.component
  }
}

resource "aws_ssm_parameter" "userpool_client_id" {
  name  = "${var.ssm_prefix}/userpool-client-id"
  type  = "String"
  value = local.userpool_client_id

  tags = {
    Component = var.component
  }
}

resource "aws_ssm_parameter" "mcp_client_id" {
  name  = "${var.ssm_prefix}/mcp-client-id"
  type  = "String"
  value = local.mcp_client_id

  tags = {
    Component = var.component
  }
}

resource "aws_ssm_parameter" "issuer" {
  name  = "${var.ssm_prefix}/issuer"
  type  = "String"
  value = local.issuer_url

  tags = {
    Component = var.component
  }
}

# Cognito hosted UI domain prefix (e.g. "coa-dev-auth-697621333100"). The
# full origin is https://<prefix>.auth.<region>.amazoncognito.com and hosts
# /oauth2/authorize, /oauth2/token, /oauth2/userInfo, /oauth2/revoke.
# The web module needs it in the CSP `connect-src` allowlist so the SPA's
# token exchange fetch isn't blocked.
resource "aws_ssm_parameter" "user_pool_domain" {
  count = local.cognito_enabled ? 1 : 0

  name  = "${var.ssm_prefix}/userpool-domain"
  type  = "String"
  value = aws_cognito_user_pool_domain.this[0].domain

  tags = {
    Component = var.component
  }
}

resource "aws_ssm_parameter" "group_token_name" {
  name  = "${var.ssm_prefix}/authentication-group-token-name"
  type  = "String"
  value = local.ssm_group_token_name

  tags = {
    Component = var.component
  }
}

# OIDC-only: JWKS URI for token signature verification (CDK writes this
# only when provided).
resource "aws_ssm_parameter" "jwks_uri" {
  count = !local.cognito_enabled && var.oidc_settings.jwks_uri != null ? 1 : 0

  name  = "${var.ssm_prefix}/jwks-uri"
  type  = "String"
  value = var.oidc_settings.jwks_uri

  tags = {
    Component = var.component
  }
}
