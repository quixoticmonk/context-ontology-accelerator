# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "aoss_max_ocu" {
  type    = number
  default = 96
}

variable "aoss_min_ocu" {
  type    = number
  default = 2
}

variable "api_certificate_arn" {
  type    = string
  default = null
}

variable "api_domain_name" {
  type    = string
  default = null
}

variable "callback_urls" {
  type    = list(string)
  default = ["https://localhost/authenticate/"]
}

variable "cognito_custom_attributes" {
  type    = map(string)
  default = {}
}

variable "env" {
  type    = string
  default = "dev"
}

variable "hosted_zone_id" {
  type    = string
  default = null
}

variable "idp_type" {
  type    = string
  default = "COGNITO"
}

variable "initial_admin_email" {
  type    = string
  default = "nobody@amazon.com"
}

variable "initial_claims_mappings" {
  type = list(object({
    group_value  = string
    mapped_roles = list(string)
  }))
  default = []
}

variable "logout_urls" {
  type    = list(string)
  default = ["https://localhost/"]
}

variable "oidc_providers" {
  type = list(object({
    name          = string
    client_id     = string
    client_secret = string
    issuer_url    = string
    scopes        = optional(list(string), ["openid", "email", "profile"])
  }))
  default   = []
  sensitive = true
}

variable "oidc_settings" {
  type = object({
    issuer_url  = string
    client_id   = string
    jwks_uri    = optional(string)
    group_claim = optional(string, "groups")
  })
  default = null
}

variable "project_tag" {
  type    = string
  default = "semantic-context"
}

variable "refresh_token_validity_hours" {
  type    = number
  default = 12
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "resource_prefix" {
  type    = string
  default = "coa"
}

variable "saml_providers" {
  type = list(object({
    name             = string
    metadata_url     = optional(string)
    metadata_content = optional(string)
  }))
  default = []
}

variable "ui_certificate_arn" {
  type    = string
  default = null
}

variable "ui_domain_name" {
  type    = string
  default = null
}
