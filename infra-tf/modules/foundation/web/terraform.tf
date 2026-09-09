# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_version = ">= 1.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"

      # CloudFront is a global service but its APIs (and the ACM certs +
      # WAF WebACLs it consumes) are pinned to us-east-1. The caller passes
      # both the default provider and a us-east-1 aliased provider so the
      # auto WebACL SSM lookup can read the param the edge-waf module wrote
      # in us-east-1.
      configuration_aliases = [aws, aws.us_east_1]
    }
  }
}
