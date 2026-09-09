# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "cache_invalidation_table_arn" {
  description = "ARN of the cache-invalidation table."
  value       = aws_dynamodb_table.cache_invalidation.arn
}

output "cache_invalidation_table_name" {
  description = "Name of the cache-invalidation table."
  value       = aws_dynamodb_table.cache_invalidation.name
}

output "cache_invalidation_table_stream_arn" {
  description = "DynamoDB stream ARN of the cache-invalidation table. Null — the cache-invalidation table has no stream (matches the CDK)."
  value       = aws_dynamodb_table.cache_invalidation.stream_arn
}

output "resource_role_mappings_table_arn" {
  description = "ARN of the resource-role-mappings table."
  value       = aws_dynamodb_table.resource_role_mappings.arn
}

output "resource_role_mappings_table_name" {
  description = "Name of the resource-role-mappings table."
  value       = aws_dynamodb_table.resource_role_mappings.name
}

output "resource_role_mappings_table_stream_arn" {
  description = "DynamoDB stream ARN of the resource-role-mappings table (NEW_AND_OLD_IMAGES)."
  value       = aws_dynamodb_table.resource_role_mappings.stream_arn
}

output "roles_table_arn" {
  description = "ARN of the roles table."
  value       = aws_dynamodb_table.roles.arn
}

output "roles_table_name" {
  description = "Name of the roles table."
  value       = aws_dynamodb_table.roles.name
}

output "roles_table_stream_arn" {
  description = "DynamoDB stream ARN of the roles table (NEW_AND_OLD_IMAGES)."
  value       = aws_dynamodb_table.roles.stream_arn
}
