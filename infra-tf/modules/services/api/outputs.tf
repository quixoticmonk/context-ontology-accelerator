# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "api_endpoint" {
  description = "REST API base URL. When a custom domain is configured this is the custom domain URL; otherwise the default execute-api URL."
  value       = var.custom_domain != null ? "https://${var.custom_domain.api_domain_name}" : "https://${aws_api_gateway_rest_api.this.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.this.stage_name}"
}

output "api_id" {
  description = "REST API ID."
  value       = aws_api_gateway_rest_api.this.id
}

output "authorizer_fn_arn" {
  description = "Custom authorizer Lambda ARN."
  value       = aws_lambda_function.authorizer.arn
}

output "cache_invalidation_dlq_arn" {
  description = "DLQ ARN for cache-invalidation events that failed all retries. Alarm rings on any message here."
  value       = aws_sqs_queue.cache_invalidation_dlq.arn
}

output "cache_invalidation_fn_arn" {
  description = "Cache-invalidation Lambda ARN."
  value       = aws_lambda_function.cache_invalidation.arn
}

output "stage_arn" {
  description = "API Gateway stage ARN."
  value       = aws_api_gateway_stage.this.arn
}

output "stage_name" {
  description = "API Gateway stage name."
  value       = aws_api_gateway_stage.this.stage_name
}

output "web_acl_arn" {
  description = "Effective REGIONAL WAF WebACL ARN attached to the stage (caller-provided or auto-created)."
  value       = local.effective_web_acl_arn
}
