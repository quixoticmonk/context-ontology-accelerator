# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "web_acl_arn" {
  description = "CLOUDFRONT-scope WAF WebACL ARN for the web distribution."
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_id" {
  description = "CLOUDFRONT-scope WAF WebACL ID."
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_ssm_parameter_name" {
  description = "SSM parameter name holding the CLOUDFRONT WebACL ARN (read cross-region by the web distribution)."
  value       = aws_ssm_parameter.cloudfront_web_acl_arn.name
}
