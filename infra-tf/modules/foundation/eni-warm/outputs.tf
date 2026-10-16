# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "function_names" {
  description = "Map of combo key → warmer function name. Service stacks don't invoke these; the names are published for operational visibility (CloudWatch log group lookup, cost allocation)."
  value       = { for k, fn in aws_lambda_function.warm : k => fn.function_name }
}

output "function_arns" {
  description = "Map of combo key → warmer function ARN."
  value       = { for k, fn in aws_lambda_function.warm : k => fn.arn }
}

output "role_arn" {
  description = "Shared execution-role ARN for all warmer Lambdas."
  value       = aws_iam_role.exec.arn
}

# A synthetic marker service modules can read via SSM so a later stack can
# `depends_on = [data.aws_ssm_parameter.eni_warm_ready]` without having to
# know the function ARNs. Value is the concatenated SHA of every warmer
# function ARN — changes whenever a combo is added or removed, so stacks
# that pin to it re-plan when the warmer set grows.
output "ready_marker" {
  description = "Opaque marker that changes whenever the set of warmer functions changes. Published to SSM by the foundation stack; consumer stacks data-source it to form an implicit dependency on the warmers' creation."
  value       = sha1(join(",", sort([for fn in aws_lambda_function.warm : fn.arn])))
}
