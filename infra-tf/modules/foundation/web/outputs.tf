# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "distribution_arn" {
  description = "CloudFront distribution ARN (for WAF association and IAM policies)."
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_domain_name" {
  description = "CloudFront distribution domain name (e.g. dxxxx.cloudfront.net)."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.this.id
}

output "website_bucket_arn" {
  description = "ARN of the private website content bucket."
  value       = aws_s3_bucket.website.arn
}

output "website_bucket_name" {
  description = "Name of the private website content bucket."
  value       = aws_s3_bucket.website.bucket
}
