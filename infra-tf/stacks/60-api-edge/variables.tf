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

variable "api_web_acl_arn" {
  type    = string
  default = null
}

variable "cloudfront_web_acl_arn" {
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

variable "idp_type" {
  type    = string
  default = "COGNITO"
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

variable "ui_certificate_arn" {
  type    = string
  default = null
}

variable "ui_domain_name" {
  type    = string
  default = null
}

