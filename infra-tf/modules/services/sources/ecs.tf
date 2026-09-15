# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Two ECS clusters (one per pipeline). Task definitions, services,
# ECR repos, and per-task IAM land in sub-turns 2-3 (database and
# documents pipelines respectively).

# ═════════════════════════════════════════════════════════════════════
#  Database Enrichment cluster
# ═════════════════════════════════════════════════════════════════════
# Hosts the sources-db-enrichment-agent Fargate task. Container
# Insights left at the default (disabled) — the CDK doesn't enable
# it for this cluster, and enrichment tasks have not exhibited the
# silent-OOM behavior that motivated Container Insights on the
# KG-build cluster.
resource "aws_ecs_cluster" "db_enrichment" {
  name = local.db_enrichment_cluster_name

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "db_enrichment" {
  # checkov:skip=CKV_AWS_338:30-day retention is the current operational minimum for this non-regulated workload. Bump to >= 365 if compliance requirements change.
  name              = "/ecs/${var.name_prefix}-sources-db-enrichment-agent"
  retention_in_days = 30
  kms_key_id        = var.logs_kms_key_arn

  tags = local.tags

  lifecycle {
    # CDK: RETAIN in prod, DESTROY elsewhere. Prod destroy needs an
    # explicit remove-and-reapply — this line documents the intent.
    prevent_destroy = false
  }
}

# ═════════════════════════════════════════════════════════════════════
#  Documents KG-Build cluster
# ═════════════════════════════════════════════════════════════════════
# Hosts the sources-doc-kg-build Fargate task. Container Insights
# ENABLED because kg-build tasks have died with no exit code and no
# memory data, leaving OOM impossible to confirm without task-level
# CPU/memory metrics.
resource "aws_ecs_cluster" "kg_build" {
  name = local.kg_build_cluster_name

  setting {
    name  = "containerInsights"
    value = "enhanced" # v2 (matches CDK containerInsightsV2 = ENABLED)
  }

  tags = local.tags
}

resource "aws_cloudwatch_log_group" "kg_build" {
  # checkov:skip=CKV_AWS_338:30-day retention is the current operational minimum for this non-regulated workload. Bump to >= 365 if compliance requirements change.
  name              = "/ecs/${var.name_prefix}-sources-doc-kg-build"
  retention_in_days = 30
  kms_key_id        = var.logs_kms_key_arn

  tags = local.tags
}
