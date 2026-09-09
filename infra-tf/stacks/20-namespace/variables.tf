# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "api_certificate_arn" {
  type    = string
  default = null
}

variable "api_domain_name" {
  type    = string
  default = null
}

variable "env" {
  type    = string
  default = "dev"
}

variable "hosted_zone_id" {
  type    = string
  default = null
}

variable "project_tag" {
  type    = string
  default = "semantic-context"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "resource_prefix" {
  type    = string
  default = "coa"
}

variable "smus_admin_principal_arns" {
  type    = list(string)
  default = []
}

variable "smus_require_mfa" {
  type    = bool
  default = false
}

variable "ui_certificate_arn" {
  type    = string
  default = null
}

variable "ui_domain_name" {
  type    = string
  default = null
}
