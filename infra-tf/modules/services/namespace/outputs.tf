# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "domain_arn" {
  description = "DataZone (SMUS) domain ARN."
  value       = aws_datazone_domain.this.arn
}

output "domain_id" {
  description = "DataZone (SMUS) domain ID."
  value       = aws_datazone_domain.this.id
}

output "dz_project_access_role_arn" {
  description = "Shared role assumed by service Lambdas for DataZone project operations."
  value       = aws_iam_role.dz_project_access.arn
}

output "grants_api_fn_arn" {
  description = "Grants API Lambda ARN."
  value       = aws_lambda_function.grants_api.arn
}

output "login_role_arn" {
  description = "SMUS admin login role ARN. Assumed via console to reach the SMUS UI."
  value       = aws_iam_role.login.arn
}

output "namespace_api_fn_arn" {
  description = "Namespace API Lambda ARN. Handles create + list + delete-trigger."
  value       = aws_lambda_function.namespace_api.arn
}

output "namespace_deletion_state_machine_arn" {
  description = "Step Functions state machine ARN for the namespace deletion pipeline."
  value       = aws_sfn_state_machine.namespace_deletion.arn
}

output "namespaces_table_arn" {
  description = "Namespaces DDB table ARN."
  value       = aws_dynamodb_table.namespaces.arn
}

output "namespaces_table_name" {
  description = "Namespaces DDB table name."
  value       = aws_dynamodb_table.namespaces.name
}

output "platform_roles_api_fn_arn" {
  description = "Platform Roles API Lambda ARN."
  value       = aws_lambda_function.platform_roles_api.arn
}

output "roles_api_fn_arn" {
  description = "Roles API Lambda ARN (namespace-scoped role list/get)."
  value       = aws_lambda_function.roles_api.arn
}

output "system_project_id" {
  description = "DataZone system project ID (owns shared form and asset types)."
  value       = local.system_project_id
}
