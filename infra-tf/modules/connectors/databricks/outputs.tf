# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "function_arn" {
  description = "Connector Lambda ARN. Register as an Athena LAMBDA data catalog with `aws athena create-data-catalog --type LAMBDA --parameters function=<this>`."
  value       = aws_lambda_function.this.arn
}

output "function_name" {
  description = "Connector Lambda function name. Carries the reserved `-managed-` segment in COA-managed mode."
  value       = aws_lambda_function.this.function_name
}

output "role_arn" {
  description = "Connector execution role ARN. A customer's trust policy references this role when `datasource-access` roles trust the connector."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Connector execution role name."
  value       = aws_iam_role.this.name
}

output "spill_bucket_name" {
  description = "Spill bucket name."
  value       = aws_s3_bucket.spill.id
}

output "spill_bucket_arn" {
  description = "Spill bucket ARN."
  value       = aws_s3_bucket.spill.arn
}

output "spill_kms_key_arn" {
  description = "Spill CMK ARN. Carries the `<resource_prefix>:connector-spill = true` tag that COA's query role's kms:Decrypt grant matches on."
  value       = aws_kms_key.spill.arn
}

output "log_group_name" {
  description = "CloudWatch Logs group backing the connector Lambda."
  value       = aws_cloudwatch_log_group.this.name
}

output "function_arn_ssm_parameter" {
  description = "SSM Parameter Store path where the function ARN is published."
  value       = aws_ssm_parameter.function_arn.name
}

output "role_arn_ssm_parameter" {
  description = "SSM Parameter Store path where the role ARN is published."
  value       = aws_ssm_parameter.role_arn.name
}
