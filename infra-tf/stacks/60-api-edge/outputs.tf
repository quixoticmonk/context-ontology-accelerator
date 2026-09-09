# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "api_endpoint" {
  value = module.api.api_endpoint
}

output "api_id" {
  value = module.api.api_id
}

output "cloudfront_distribution_domain_name" {
  value = module.web.distribution_domain_name
}

output "cloudfront_distribution_id" {
  value = module.web.distribution_id
}
