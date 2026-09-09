# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "repository_urls" {
  description = "Map of repository logical key to repository URL."
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "repository_arns" {
  description = "Map of repository logical key to repository ARN."
  value       = { for k, r in aws_ecr_repository.this : k => r.arn }
}
