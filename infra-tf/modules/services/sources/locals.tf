# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  is_prod               = var.env == "prod"
  force_destroy_buckets = !local.is_prod

  # ── Physical names (match CDK prefixed()) ──────────────────────────
  sources_table_name          = "${var.name_prefix}-sources"
  source_scan_jobs_table_name = "${var.name_prefix}-source-scan-jobs"

  sources_bucket_name      = "${var.name_prefix}-sources-data-${data.aws_caller_identity.current.account_id}"
  sources_access_logs_name = "${var.name_prefix}-sources-logs-${data.aws_caller_identity.current.account_id}"

  db_enrichment_cluster_name = "${var.name_prefix}-sources-db-enrichment-cluster"
  kg_build_cluster_name      = "${var.name_prefix}-sources-doc-kg-build-cluster"

  # ── Federated catalog prefix ────────────────────────────────────────
  # Glue connections/catalogs are named `{sanitizedPrefix}ds_{hash}` by
  # the provisioner. Lowercased, strip non-alphanumerics. IAM conditions
  # elsewhere in this module (added in sub-turns 2-3) scope to this exact
  # pattern.
  federated_catalog_prefix = "${lower(replace("${var.name_prefix}", "/[^a-z0-9]/", ""))}ds_"

  # ── Common tags ────────────────────────────────────────────────────
  tags = {
    Component = var.component
  }
}
