# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_version = ">= 1.14"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # >= 6.4 so action "aws_cloudfront_create_invalidation" is available
      # (invalidation.tf). All other resources in this module work on 6.0+.
      version = ">= 6.4, < 7.0"

      # CloudFront is a global service but its APIs (and the ACM certs +
      # WAF WebACLs it consumes) are pinned to us-east-1. The caller passes
      # both the default provider and a us-east-1 aliased provider so the
      # auto WebACL SSM lookup can read the param the edge-waf module wrote
      # in us-east-1.
      configuration_aliases = [aws, aws.us_east_1]
    }
  }
}
