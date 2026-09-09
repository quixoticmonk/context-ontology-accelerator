# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "guardrail_arn" {
  description = "Primary guardrail ARN (LLM input/output boundary; content filters + PII anonymization)."
  value       = aws_bedrock_guardrail.this.guardrail_arn
}

output "guardrail_id" {
  description = "Primary guardrail ID."
  value       = aws_bedrock_guardrail.this.guardrail_id
}

output "guardrail_version" {
  description = "Primary guardrail published version."
  value       = aws_bedrock_guardrail_version.this.version
}

output "retrieval_guardrail_arn" {
  description = "Retrieval guardrail ARN (ingested/retrieved content screening; content filters only, no PII policy)."
  value       = aws_bedrock_guardrail.retrieval.guardrail_arn
}

output "retrieval_guardrail_id" {
  description = "Retrieval guardrail ID."
  value       = aws_bedrock_guardrail.retrieval.guardrail_id
}

output "retrieval_guardrail_version" {
  description = "Retrieval guardrail published version."
  value       = aws_bedrock_guardrail_version.retrieval.version
}
