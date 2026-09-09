# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "agent_runtime_arn" {
  description = "AgentCore Runtime ARN for the Context Manager."
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn
}

output "agent_runtime_id" {
  description = "AgentCore Runtime ID."
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_id
}

output "agent_runtime_name" {
  description = "AgentCore Runtime name (underscores; hyphens replaced)."
  value       = local.runtime_name
}

output "agentcore_security_group_id" {
  description = "Security group attached to AgentCore Runtime ENIs."
  value       = aws_security_group.agentcore.id
}

output "aoss_proxy_fn_arn" {
  description = "AOSS search proxy Lambda ARN (shared with MCP stack)."
  value       = aws_lambda_function.aoss_proxy.arn
}

output "runtime_role_arn" {
  description = "AgentCore Runtime IAM role ARN (consumer query principal)."
  value       = aws_iam_role.runtime.arn
}
