# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  # ── Naming ──────────────────────────────────────────────────────────
  # Function name carries the reserved `-managed-` segment in COA-managed mode
  # to tell this deployment apart from a customer-deployed connector in the
  # same account. A customer-deployed function MUST NOT use `-managed-`
  # (connectors/databricks/README.md documents this).
  name_prefix = "${var.resource_prefix}-${var.env}"
  function_name = (
    var.config_source == "coa-managed"
    ? "${local.name_prefix}-managed-databricks-coa-connector"
    : "${local.name_prefix}-databricks-coa-connector"
  )

  # Managed deployments pin the role name because a customer's trust policy
  # names it; a customer-deployed connector has no such constraint.
  role_name = (
    var.config_source == "coa-managed"
    ? "${local.name_prefix}-databricks-connector-role"
    : null
  )

  # ── Spill paths (COA's invoke contract) ─────────────────────────────
  # Spill is read by Athena using the querying principal's forward-access-
  # session credentials. The grant can't be pinned to a bucket (customer
  # owns it), so the key PREFIX bounds it. Form: connectors/<id>/spills/
  spill_prefix      = "connectors/databricks/spills"
  spill_prefix_glob = "connectors/databricks/spills/*"
  spill_bucket_name = "${local.function_name}-spill"

  # ── Tag conventions (do not override; they are the invoke contract) ─
  # From libs/ts-shared/src/constants.ts:
  #   CONNECTOR_TAG_KEY = `${BRAND}:connector`           // coa:connector
  #   CONNECTOR_SPILL_KMS_TAG_KEY = `${BRAND}:connector-spill`  // coa:connector-spill
  #
  # The connector-tag match is what makes Athena's lambda:InvokeFunction
  # grant hit this Lambda; without it the first scan is denied.
  connector_tag_key           = "${var.resource_prefix}:connector"
  connector_tag_value         = "true"
  connector_spill_kms_tag_key = "${var.resource_prefix}:connector-spill"

  base_tags = merge(var.tags, {
    (local.connector_tag_key) = local.connector_tag_value
    Component                 = "databricks-connector"
    Mode                      = var.config_source
  })

  # KMS key gets its own tag (CONNECTOR_SPILL_KMS_TAG) so operators can
  # distinguish spill keys from any other connector keys with one filter.
  spill_kms_tags = merge(local.base_tags, {
    (local.connector_spill_kms_tag_key) = "true"
  })

  # ── Environment variables ───────────────────────────────────────────
  # JAVA_TOOL_OPTIONS is MANDATORY on Java 17+. Arrow reaches into
  # java.nio internals; without the --add-opens, metadata calls succeed
  # while every read fails with "Failed to initialize MemoryUtil".
  base_environment = {
    JAVA_TOOL_OPTIONS        = "--add-opens=java.base/java.nio=ALL-UNNAMED"
    spill_prefix             = local.spill_prefix
    disable_spill_encryption = "false"
    spill_bucket             = aws_s3_bucket.spill.id
    DATABRICKS_CONFIG_SOURCE = var.config_source
    CONFIG_SOURCE            = var.config_source
  }

  max_rows_env = (
    var.databricks_max_rows_per_table != null
    ? { DATABRICKS_MAX_ROWS_PER_TABLE = tostring(var.databricks_max_rows_per_table) }
    : {}
  )

  managed_mode_env = (
    var.config_source == "coa-managed"
    ? {
      COA_PREFIX               = var.resource_prefix
      COA_ENV_NAME             = var.env
      COA_CONFIG_SSM_PREFIX    = "/${var.resource_prefix}/${var.env}/connectors/databricks/sources"
      COA_FUNCTION_NAME_PREFIX = local.name_prefix
    }
    : {}
  )

  environment_mode_env = (
    var.config_source == "environment"
    ? merge(
      var.databricks_workspace_host != null ? { DATABRICKS_WORKSPACE_HOST = var.databricks_workspace_host } : {},
      var.databricks_warehouse_id != null ? { DATABRICKS_WAREHOUSE_ID = var.databricks_warehouse_id } : {},
      var.databricks_catalog != null ? { DATABRICKS_CATALOG = var.databricks_catalog } : {},
      var.databricks_schema != null ? { DATABRICKS_SCHEMA = var.databricks_schema } : {},
      var.credential_secret_arn != null ? { CREDENTIAL_SECRET_ARN = var.credential_secret_arn } : {},
    )
    : {}
  )

  environment = merge(
    local.base_environment,
    local.max_rows_env,
    local.managed_mode_env,
    local.environment_mode_env,
  )

  # ── Build-time: fat-jar packaging ───────────────────────────────────
  # Lambda counts the EXTRACTED package against its 250MB limit and does
  # NOT extract a nested jar — the fat jar ships at lib/<jar>, on the
  # classpath, counted at its own size. The archive_file data source
  # produces the zip Lambda wants.
  jar_file     = basename(var.jar_path)
  package_root = "${path.module}/.build/${local.function_name}"
}
