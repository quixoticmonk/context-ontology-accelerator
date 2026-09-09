# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "callback_urls" {
  description = "OAuth callback (redirect) URLs for the web app user pool client. Must be a non-empty list; Cognito requires at least one."
  type        = list(string)
  default     = ["https://localhost/authenticate/"]
}

variable "cognito_custom_attributes" {
  description = "Custom Cognito user pool attributes. Map key is the attribute name, value is the data type: \"string\" or \"number\". Applied only in COGNITO/SAML modes."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for v in values(var.cognito_custom_attributes) : contains(["string", "number"], v)])
    error_message = "cognito_custom_attributes values must be either \"string\" or \"number\"."
  }
}

variable "component" {
  description = "Component tag applied to every resource in this module."
  type        = string
  default     = "foundation"
}

variable "custom_domain_ui_domain_name" {
  description = "Custom UI domain name. When set, an authenticate callback URL derived from this domain is merged into the web app client callback URLs. Null to skip."
  type        = string
  default     = null
}

variable "idp_type" {
  description = "Identity provider mode. COGNITO provisions a standalone Cognito user pool, SAML federates enterprise IdPs through Cognito, OIDC integrates a direct external OIDC IdP with no Cognito resources."
  type        = string
  default     = "COGNITO"

  validation {
    condition     = contains(["COGNITO", "SAML", "OIDC"], var.idp_type)
    error_message = "idp_type must be one of COGNITO, SAML, or OIDC."
  }
}

variable "initial_admin_email" {
  description = "Email address for the initial admin user seeded in COGNITO/SAML modes. Also used as the user pool username."
  type        = string
  default     = "nobody@amazon.com"
}

variable "logout_urls" {
  description = "OAuth logout (sign-out redirect) URLs for the web app user pool client."
  type        = list(string)
  default     = ["https://localhost/"]
}

variable "name_prefix" {
  description = "Physical resource name prefix (<resource_prefix>-<env>)."
  type        = string
}

variable "oidc_providers" {
  description = "OIDC identity providers federated through Cognito (COGNITO/SAML modes). Each entry registers an aws_cognito_identity_provider of type OIDC keyed by name."
  type = list(object({
    name          = string
    client_id     = string
    client_secret = string
    issuer_url    = string
    scopes        = optional(list(string), ["openid", "email", "profile"])
  }))
  default = []
}

variable "oidc_settings" {
  description = "Direct external OIDC IdP settings. Required when idp_type is OIDC (no Cognito is provisioned). issuer_url and client_id must be non-empty; group_claim defaults to \"groups\"."
  type = object({
    issuer_url  = string
    client_id   = string
    jwks_uri    = optional(string)
    group_claim = optional(string, "groups")
  })
  default = null
}

variable "refresh_token_validity_hours" {
  description = "Refresh token validity in hours for the web app user pool client."
  type        = number
  default     = 12
}

variable "saml_providers" {
  description = "SAML identity providers to register with the Cognito user pool (SAML mode). Provide exactly one of metadata_url or metadata_content per entry."
  type = list(object({
    name             = string
    metadata_url     = optional(string)
    metadata_content = optional(string)
  }))
  default = []
}

variable "ssm_prefix" {
  description = "SSM parameter root (e.g. /coa). Runtime services read auth config under this path."
  type        = string
}
