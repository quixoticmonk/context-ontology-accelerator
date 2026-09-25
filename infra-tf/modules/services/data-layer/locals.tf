# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  # ── Lambda function name (matches CDK prefixed() output) ──────────
  fn_api = "${var.name_prefix}-data-layer-api"

  # ── Common tags ────────────────────────────────────────────────────
  tags = {
    Component = var.component
  }

  # Deterministic zip content hash — triggers Lambda redeploy when the
  # Makefile rebuilds the zip. `try(..., null)` keeps `plan` working
  # before the zip has been built (points the user at `make build-lambdas`
  # only when they actually apply against a missing file).
  lambda_zip_hash = try(filebase64sha256(var.data_layer_zip_path), null)

  # Runtime env for the data-layer handler. The CDK reads these two
  # ARNs from SSM at deploy time; here the root wires them in directly
  # from the producing modules' outputs (idiomatic TF — no runtime SSM
  # read). Each var is optional: only emit the env key when set.
  api_env = merge(
    {
      ALLOWED_ORIGIN   = var.allowed_origin
      NAMESPACES_TABLE = var.namespaces_table_name
    },
    var.serve_runtime_arn != null ? { AGENTCORE_RUNTIME_ARN = var.serve_runtime_arn } : {},
    var.ontology_engine_api_fn_arn != null ? { ONTOLOGY_PROXY_LAMBDA_ARN = var.ontology_engine_api_fn_arn } : {},
  )

  # Direct-through Lambda invoke target (ontology only). Schema queries
  # bypass the Context Manager. Filtered to non-null. Metric-catalog
  # queries used to be proxied here too but are now served in-process
  # by the data-layer handler.
  invoke_lambda_arns = compact([
    var.ontology_engine_api_fn_arn,
  ])

  # Whether any invoke target is wired. When false the execution role
  # gets only the VPC-access managed policy (no inline invoke policy,
  # which would otherwise be an empty — invalid — IAM document).
  api_policy_enabled = (var.serve_runtime_arn != null && var.serve_runtime_arn != "") || length(local.invoke_lambda_arns) > 0
}
