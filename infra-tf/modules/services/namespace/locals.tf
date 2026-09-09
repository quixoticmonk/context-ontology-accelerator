# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  # ── Physical names (match CDK prefixed() outputs) ─────────────────
  namespaces_table_name = "${var.name_prefix}-namespaces"

  # Domain / project naming — matches CDK's this.prefixed(...) calls.
  smus_domain_name       = "${var.name_prefix}-smus-catalog"
  system_project_name    = "${var.name_prefix}-system"
  project_profile_name   = "${var.name_prefix}-default"
  smus_exec_role_name    = "${var.name_prefix}-smus-exec"
  dz_project_access_name = "${var.name_prefix}-dz-project-access"
  login_role_name        = "${var.name_prefix}-smus-login"

  # ── Lambda function names ─────────────────────────────────────────
  fn_namespace_api      = "${var.name_prefix}-namespace-api"
  fn_roles_api          = "${var.name_prefix}-roles-api"
  fn_platform_roles_api = "${var.name_prefix}-platform-roles-api"
  fn_grants_api         = "${var.name_prefix}-grants-api"
  fn_del_sources        = "${var.name_prefix}-ns-deletion-sources"
  fn_del_metrics        = "${var.name_prefix}-ns-deletion-metrics"
  fn_del_ontology       = "${var.name_prefix}-ns-deletion-ontology"
  fn_del_platform       = "${var.name_prefix}-ns-deletion-platform"
  fn_del_finalize       = "${var.name_prefix}-ns-deletion-finalize"
  fn_del_mark_failed    = "${var.name_prefix}-ns-deletion-mark-failed"

  # Cross-service Lambda name deps — these live in other modules
  # (sources, metric-service) but are constructed by convention here
  # because those modules deploy AFTER this one. Same pattern the CDK
  # uses (this.prefixed(...) to synthesize invoke targets).
  fn_sources_api = "${var.name_prefix}-sources-api"
  fn_metric_api  = "${var.name_prefix}-metric-api"

  # ── Common tags ────────────────────────────────────────────────────
  tags = {
    Component = var.component
  }

  # ── SMUS service principals ────────────────────────────────────────
  # All 10 principals with the 4 required STS actions, matching CDK.
  smus_principals = [
    "datazone.amazonaws.com",
    "sagemaker.amazonaws.com",
    "glue.amazonaws.com",
    "bedrock.amazonaws.com",
    "scheduler.amazonaws.com",
    "lakeformation.amazonaws.com",
    "airflow-serverless.amazonaws.com",
    "athena.amazonaws.com",
    "redshift.amazonaws.com",
    "emr-serverless.amazonaws.com",
  ]

  # ── Admin login role trust principals ──────────────────────────────
  # Default: <account>/Admin. Override via var.smus_admin_principal_arns.
  # The CDK validates the ARNs at synth; TF validation on the variable
  # itself already enforces the same regex.
  default_admin_arn    = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/Admin"
  admin_principal_arns = length(var.smus_admin_principal_arns) > 0 ? var.smus_admin_principal_arns : [local.default_admin_arn]

  # ── AOSS deletion-pipeline access ──────────────────────────────────
  # Only wire GraphRAG index cleanup when the caller passes both AOSS
  # inputs (matches CDK behavior — the DeleteSources handler no-ops
  # when OSS_ENDPOINT is unset).
  aoss_deletion_enabled = var.opensearch_endpoint != null && var.opensearch_collection_name != null
}
