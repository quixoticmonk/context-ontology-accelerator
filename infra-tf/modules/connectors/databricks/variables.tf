# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

# ── Required inputs ───────────────────────────────────────────────────

variable "jar_path" {
  description = "Local filesystem path to the Databricks connector fat jar (built from connectors/databricks via `mvn package`, published as `databricks-connector-<version>.jar`). The module uploads it to a temp zip at plan time; keep the file stable so Lambda doesn't redeploy on every apply."
  type        = string
}

variable "resource_prefix" {
  description = "Deployment resource prefix, e.g. `coa`. Function name is `<resource_prefix>-<env>-databricks-coa-connector` for customer deployments or `<resource_prefix>-<env>-managed-databricks-coa-connector` for COA-managed. The `-managed-` segment is reserved."
  type        = string
  default     = "coa"
}

variable "env" {
  description = "Deployment environment name (e.g. `dev`, `prd`). Combined with `resource_prefix` to build the function name. In the COA-managed mode, SSM parameter paths are also scoped by this value."
  type        = string
  default     = "dev"
}

# ── Mode selector ─────────────────────────────────────────────────────

variable "config_source" {
  description = <<-EOT
    Which configuration shape the connector reads at request time:

    - `environment` (default) — single Databricks endpoint, config from Lambda
      env vars (DATABRICKS_WORKSPACE_HOST, DATABRICKS_WAREHOUSE_ID,
      DATABRICKS_CATALOG, DATABRICKS_SCHEMA, CREDENTIAL_SECRET_ARN).
      Customer-deployed in the customer's own AWS account against one
      workspace+warehouse.

    - `coa-managed` — one Lambda serves EVERY DATABRICKS_SQL_WAREHOUSE
      source in one COA environment. Config per source is resolved from
      SSM Parameter Store under `/<resource_prefix>/<env>/connectors/
      databricks/sources/<sourceId>`. The sources API (`infra-tf/modules/
      services/sources`) owns writing those parameters.
  EOT
  type        = string
  default     = "environment"

  validation {
    condition     = contains(["environment", "coa-managed"], var.config_source)
    error_message = "config_source must be either 'environment' or 'coa-managed'."
  }
}

# ── Query-principal grants ────────────────────────────────────────────

variable "query_role_arns" {
  description = "IAM role ARNs allowed to invoke the connector Lambda and read its spill. In a COA-integrated deployment this is COA's serve runtime role plus the sources discovery role (reading /<prefix>/<env>/serve/runtime-role-arn and /<prefix>/<env>/sources/db-connector-role-arn from SSM). Leave empty for a connector-only test deploy."
  type        = list(string)
  default     = []
}

# ── Operational knobs ─────────────────────────────────────────────────

variable "memory_size_mb" {
  description = "Lambda memory in MB. Default 3008 matches upstream — the connector reads the whole predicate-matching row set to answer `GROUP BY` (Athena federation can't express aggregation)."
  type        = number
  default     = 3008
}

variable "timeout_seconds" {
  description = "Lambda timeout in seconds. Default 600 covers a stopped SQL Warehouse resuming ahead of a large read. A runaway read is bounded by `databricks_max_rows_per_table` and the statement/socket timeouts inside the jar."
  type        = number
  default     = 600
}

variable "databricks_max_rows_per_table" {
  description = "Row ceiling the connector applies to any single table read. Must match the Java default (DEFAULT_MAX_ROWS_PER_TABLE in `coa_sources_connectors_databricks`) if left null, which is 2,000,000. Set higher only when a legitimately large table is being truncated. The `ConnectorRowsReturned` CloudWatch alarm threshold tracks this value."
  type        = number
  default     = null
}

# ── Environment-mode config (unused when `config_source == 'coa-managed'`) ─

variable "databricks_workspace_host" {
  description = "`environment` mode only. Databricks workspace host, e.g. `dbc-abcd-ef01.cloud.databricks.com`."
  type        = string
  default     = null
}

variable "databricks_warehouse_id" {
  description = "`environment` mode only. Databricks SQL Warehouse id."
  type        = string
  default     = null
}

variable "databricks_catalog" {
  description = "`environment` mode only. Unity Catalog name scoped by the credential."
  type        = string
  default     = null
}

variable "databricks_schema" {
  description = "`environment` mode only. Default schema within the Unity Catalog. Required when the credential has access to more than one schema — scope exactly to what you intend to expose."
  type        = string
  default     = null
}

variable "credential_secret_arn" {
  description = "`environment` mode only. Secrets Manager ARN pointing to a secret with either `{token: ...}` (personal access token) or `{client_id: ..., client_secret: ...}` (OAuth m2m). A secret carrying both is refused."
  type        = string
  default     = null
}

variable "credential_kms_key_arn" {
  description = "Optional. Required when `credential_secret_arn` is encrypted with a customer-managed key — no existing grant covers it and every read fails `AccessDenied` without it."
  type        = string
  default     = null
}

# ── Networking ─────────────────────────────────────────────────────────

variable "vpc_id" {
  description = "Optional VPC id. When set, the Lambda runs with VPC attachments. Required for workspaces reachable only via PrivateLink. Both `vpc_id` and `subnet_ids` must be set together, or both left null."
  type        = string
  default     = null

  validation {
    condition     = (var.vpc_id == null) == (length(var.subnet_ids) == 0)
    error_message = "vpc_id and subnet_ids must be set together; set both or neither."
  }
}

variable "subnet_ids" {
  description = "Private subnets with egress route to the Databricks workspace (NAT or PrivateLink endpoint), Secrets Manager, KMS, and S3. See connectors/README.md."
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "Optional security groups for the Lambda. When null and VPC is set, the module creates one with HTTPS egress only (443/tcp to 0.0.0.0/0)."
  type        = list(string)
  default     = null
}

# ── Alarm topic ───────────────────────────────────────────────────────

variable "alarm_topic_arn" {
  description = "Optional SNS topic ARN. When set, every CloudWatch alarm this module creates publishes to it on breach."
  type        = string
  default     = null
}

# ── Lifecycle ─────────────────────────────────────────────────────────

variable "retain_spill_on_destroy" {
  description = "When true (prod convention), the spill bucket + CMK survive `terraform destroy` so an in-flight investigation of a hung query doesn't lose evidence. Default false — spill is scratch, every query older than itself is garbage."
  type        = bool
  default     = false
}

variable "log_retention_in_days" {
  description = "CloudWatch Logs retention for `/aws/lambda/<function_name>`. Default 30 days matches the CDK."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Additional tags to apply to every resource. The module always applies `coa:connector = true` on the Lambda and `coa:connector-spill = true` on the KMS key, since those tags are the invoke contract — do not override them."
  type        = map(string)
  default     = {}
}
