# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# v0.3.5 — Databricks per-source parameter audit tripwire.
#
# A cross-source credential repoint (PutParameter overwriting one source's
# config with another's secret ARN and namespace) resolves SUCCESSFULLY, so
# no other metric can see it. The tripwire logs every write under the
# Databricks per-source config path to a dedicated log group, applies an
# allowlist for the sources-API role via a metric filter, and alarms on
# any write by a principal outside the allowlist.
#
# PREREQUISITE: a CloudTrail trail must be logging management events in
# this account and region. Without one the alarm never fires, and the
# scope on the sources-API SSM-write policy (sources_api.tf
# DatabricksSourceConfig statement) is the only control.
#
# Comes from infra/lib/stacks/services/sources-stack.ts @ v0.3.5
# (parameterAuditLogGroup / Databricks{Parameter,ParameterBatchDelete}Rule
# / DatabricksUnexpectedParameterWriteFilter / ...Alarm).

locals {
  sources_namespace                = "COA/Sources"
  databricks_ssm_root              = "${var.ssm_prefix}/${var.env}/connectors/databricks"
  databricks_sources_config_prefix = "${local.databricks_ssm_root}/sources"
  databricks_write_path_prefix     = "${local.databricks_sources_config_prefix}/"
}

# ── Log group ──────────────────────────────────────────────────────────
# /aws/events/ prefix is the conventional home for EventBridge log targets
# and keeps the delivery resource policy narrow. One year retention — this
# is the audit record an investigation reads to decide whether a write was
# a repoint, so it has to outlive the incident.
resource "aws_cloudwatch_log_group" "databricks_parameter_audit" {
  name              = "/aws/events/${var.name_prefix}-databricks-parameter-writes"
  retention_in_days = 365
  kms_key_id        = var.logs_kms_key_arn

  tags = local.tags
}

# ── EventBridge rule — single-parameter writes ─────────────────────────
# EVERY write under the path is logged, legitimate ones included: the
# allowlist is applied by the metric filter below, not by the rule.
# `anything-but` in an event pattern does NOT match an ABSENT key, so a
# writer with no sessionContext (an IAM user, or a root call — the most
# suspicious principal class) would be silently exempted by a pattern-
# level allowlist. CloudWatch Logs filter syntax can say NOT EXISTS, so
# the allowlist lives in the metric filter below where absence is
# expressible.
resource "aws_cloudwatch_event_rule" "databricks_parameter_write" {
  name = "${var.name_prefix}-databricks-parameter-writes"
  description = join(" ", [
    "Records every write under the Databricks per-source config path for",
    "UnexpectedConnectorParameterWrite. Requires a CloudTrail trail logging",
    "management events in this account and region; this module creates none.",
  ])

  event_pattern = jsonencode({
    source      = ["aws.ssm"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ssm.amazonaws.com"]
      eventName   = ["PutParameter", "DeleteParameter"]
      requestParameters = {
        name = [{ prefix = local.databricks_write_path_prefix }]
      }
    }
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "databricks_parameter_write" {
  rule      = aws_cloudwatch_event_rule.databricks_parameter_write.name
  target_id = "LogGroup"
  arn       = aws_cloudwatch_log_group.databricks_parameter_audit.arn
}

# ── EventBridge rule — batch deletes ───────────────────────────────────
# DeleteParameters uses a different event name and `names` as a list.
# EventBridge content filters match if ANY list element matches, so one
# prefix matcher covers a batch that mixes paths — the interesting case,
# since a batch delete touching one parameter under this path is exactly
# what a repoint's cleanup would look like.
resource "aws_cloudwatch_event_rule" "databricks_parameter_batch_delete" {
  name        = "${var.name_prefix}-databricks-parameter-batch-deletes"
  description = aws_cloudwatch_event_rule.databricks_parameter_write.description

  event_pattern = jsonencode({
    source      = ["aws.ssm"]
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      eventSource = ["ssm.amazonaws.com"]
      eventName   = ["DeleteParameters"]
      requestParameters = {
        names = [{ prefix = local.databricks_write_path_prefix }]
      }
    }
  })

  tags = local.tags
}

resource "aws_cloudwatch_event_target" "databricks_parameter_batch_delete" {
  rule      = aws_cloudwatch_event_rule.databricks_parameter_batch_delete.name
  target_id = "LogGroup"
  arn       = aws_cloudwatch_log_group.databricks_parameter_audit.arn
}

# ── Metric filter — allowlist by sessionIssuer userName ────────────────
# NOT EXISTS first and it is load-bearing: a principal with no
# sessionContext (IAM user, root call) is NOT covered by the != terms,
# because a comparison against an absent field is false. Without the NOT
# EXISTS clause the filter would exempt exactly the callers least likely
# to be legitimate.
#
# cfn_exec_role_name is a module var defaulting to null: without CDK
# bootstrap we have no stack-managed CFN role to allowlist, so when it's
# null the filter checks only the sources-API role.
locals {
  databricks_issuer_field = "$.detail.userIdentity.sessionContext.sessionIssuer.userName"

  databricks_audit_filter_pattern = (
    var.cdk_cfn_exec_role_name != null
    ? "{ (${local.databricks_issuer_field} NOT EXISTS) || ((${local.databricks_issuer_field} != \"${aws_iam_role.sources_api.name}\") && (${local.databricks_issuer_field} != \"${var.cdk_cfn_exec_role_name}\")) }"
    : "{ (${local.databricks_issuer_field} NOT EXISTS) || (${local.databricks_issuer_field} != \"${aws_iam_role.sources_api.name}\") }"
  )
}

resource "aws_cloudwatch_log_metric_filter" "databricks_unexpected_write" {
  name           = "${var.name_prefix}-databricks-unexpected-parameter-write"
  log_group_name = aws_cloudwatch_log_group.databricks_parameter_audit.name
  pattern        = local.databricks_audit_filter_pattern

  metric_transformation {
    name      = "UnexpectedConnectorParameterWrite"
    namespace = local.sources_namespace
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "databricks_unexpected_write" {
  alarm_name = "${var.name_prefix}-databricks-unexpected-parameter-write"
  alarm_description = join(" ", [
    "A principal outside the allowlist wrote or deleted a Databricks per-source",
    "config parameter. Treat as a potential cross-source credential repoint:",
    "compare the parameter's credentialSecretArn and namespaceId against the",
    "source record before dismissing. A repoint resolves SUCCESSFULLY, so no",
    "other metric can see it. NOTE: this alarm depends on a CloudTrail trail",
    "logging management events in this account and region, which this module",
    "does not create — in an account without one it never fires and the",
    "parameter-write scope on the sources-API role (DatabricksSourceConfig in",
    "sources_api.tf) is the only control.",
  ])

  namespace           = local.sources_namespace
  metric_name         = "UnexpectedConnectorParameterWrite"
  statistic           = "Sum"
  period              = 300 # 5 minutes, mirrors CDK
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  # A write is a discrete event — "no data" is the normal state and MUST
  # NOT read as a breach.
  treat_missing_data = "notBreaching"

  tags = local.tags
}
