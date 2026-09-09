# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "agent_runtime_arn" {
  description = "MCP AgentCore Runtime ARN."
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn
}

output "agent_runtime_id" {
  description = "MCP AgentCore Runtime ID."
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_id
}

output "runtime_role_arn" {
  description = "MCP AgentCore Runtime execution IAM role ARN."
  value       = aws_iam_role.mcp_runtime.arn
}
