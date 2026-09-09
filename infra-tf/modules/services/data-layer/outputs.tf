# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "api_fn_arn" {
  description = "Data Layer API Lambda function ARN."
  value       = aws_lambda_function.api.arn
}

output "api_fn_name" {
  description = "Data Layer API Lambda function name."
  value       = aws_lambda_function.api.function_name
}
