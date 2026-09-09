# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

resource "aws_ssm_parameter" "runtime_arn" {
  name        = "${var.ssm_prefix}/serve/runtime-arn"
  type        = "String"
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn
  description = "AgentCore Runtime ARN for the Context Manager"
  tags        = local.tags
}

resource "aws_ssm_parameter" "runtime_role_arn" {
  name        = "${var.ssm_prefix}/serve/runtime-role-arn"
  type        = "String"
  value       = aws_iam_role.runtime.arn
  description = "AgentCore Runtime IAM role ARN (consumer query principal)"
  tags        = local.tags
}

resource "aws_ssm_parameter" "aoss_proxy_arn" {
  name        = "${var.ssm_prefix}/serve/aoss-proxy-lambda-arn"
  type        = "String"
  value       = aws_lambda_function.aoss_proxy.arn
  description = "AOSS search proxy Lambda ARN (shared with MCP stack)"
  tags        = local.tags
}
