# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "serve_runtime_arn" {
  value = module.serve.agent_runtime_arn
}

output "mcp_runtime_arn" {
  value = module.mcp.agent_runtime_arn
}
