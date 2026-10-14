# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Publish the connector's function ARN and role ARN. The sources API
# reads these at source-registration time (COA-managed mode) and the
# customer's trust policy references the role ARN (both modes).
#
# Sibling subtree (`deployment/`) rather than a deeper key under
# `sources/`: the writers and directions differ — the sources API writes
# `sources/*` and reads `deployment/*`, and a single prefix would let it
# overwrite the ARN it later reads.

resource "aws_ssm_parameter" "function_arn" {
  name        = "/${var.resource_prefix}/${var.env}/connectors/databricks/deployment/function-arn"
  type        = "String"
  value       = aws_lambda_function.this.arn
  description = "Databricks connector Lambda ARN — register as an Athena LAMBDA data catalog"
  tags        = local.base_tags
}

resource "aws_ssm_parameter" "role_arn" {
  name        = "/${var.resource_prefix}/${var.env}/connectors/databricks/deployment/role-arn"
  type        = "String"
  value       = aws_iam_role.this.arn
  description = "Databricks connector execution role ARN — named by customer trust policies"
  tags        = local.base_tags
}
