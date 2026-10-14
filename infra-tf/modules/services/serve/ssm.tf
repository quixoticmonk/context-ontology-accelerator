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
  # ENV-SCOPED, unlike this platform's other role parameters. `ssm_prefix` is
  # `/${prefix}` alone and environments share an account, so an env-less name lets a
  # sibling environment's deploy overwrite this value and the last one wins. This one
  # fails OPEN: it is read by a connector stack deployed from a separate CDK app,
  # where it becomes a lambda:InvokeFunction resource policy plus s3:GetObject on the
  # connector's spill prefix and kms:Decrypt on its spill key. The wrong value hands a
  # sibling environment's serve role a read on this environment's spilled query
  # results.
  name        = "${var.ssm_prefix}/${var.env}/serve/runtime-role-arn"
  type        = "String"
  value       = aws_iam_role.runtime.arn
  description = "AgentCore Runtime IAM role ARN (consumer query principal, env-scoped)"
  tags        = local.tags
}

resource "aws_ssm_parameter" "aoss_proxy_arn" {
  name        = "${var.ssm_prefix}/serve/aoss-proxy-lambda-arn"
  type        = "String"
  value       = aws_lambda_function.aoss_proxy.arn
  description = "AOSS search proxy Lambda ARN (shared with MCP stack)"
  tags        = local.tags
}
