# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "azs" {
  type    = list(string)
  default = ["us-east-1b", "us-east-1c"]
}

variable "env" {
  type    = string
  default = "dev"
}

variable "jdbc_peer_cidrs" {
  type    = list(string)
  default = []
}

variable "jdbc_peer_owner_id" {
  type    = string
  default = null
}

variable "jdbc_peer_region" {
  type    = string
  default = null
}

variable "jdbc_peer_vpc_id" {
  type    = string
  default = null
}

variable "jdbc_privatelink_port" {
  type    = number
  default = null
}

variable "jdbc_privatelink_private_dns" {
  type    = bool
  default = false
}

variable "jdbc_privatelink_service" {
  type    = string
  default = null
}

variable "jdbc_tgw_cidrs" {
  type    = list(string)
  default = []
}

variable "jdbc_tgw_id" {
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

variable "vpc_id" {
  type    = string
  default = null
}
