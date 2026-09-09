# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  is_prod = var.env == "prod"

  # Prod retains data; non-prod tears everything down for cheap, clean
  # re-deploys. Mirrors the CDK RemovalPolicy.RETAIN vs DESTROY +
  # autoDeleteObjects split.
  force_destroy_buckets = !local.is_prod

  account_id = data.aws_caller_identity.this.account_id

  # AOSS collection name — <name_prefix>-vector-store, matching the CDK
  # VECTOR_COLLECTION_SUFFIX constant.
  collection_name = "${var.name_prefix}-vector-store"

  # Neptune IAM data-access ARN uses the cluster *resource* ID
  # (e.g. cluster-ABCD1234...), NOT the cluster identifier.
  # Format: arn:aws:neptune-db:<region>:<account>:<cluster-resource-id>/*
  neptune_cluster_arn = "arn:aws:neptune-db:${var.region}:${local.account_id}:${aws_neptune_cluster.this.cluster_resource_id}/*"

  # S3 buckets that log to the shared access-logs target. Keyed by the
  # logical role; value carries the log prefix. Drives the versioning,
  # encryption, public-access-block, and SSL-policy fan-out via for_each.
  logged_buckets = {
    athena_results     = { bucket = aws_s3_bucket.athena_results.id, arn = aws_s3_bucket.athena_results.arn }
    athena_spill       = { bucket = aws_s3_bucket.athena_spill.id, arn = aws_s3_bucket.athena_spill.arn }
    ontology_artifacts = { bucket = aws_s3_bucket.ontology_artifacts.id, arn = aws_s3_bucket.ontology_artifacts.arn }
  }

  # ── AOSS network policy rules ──────────────────────────────────────
  # Baseline: VPCE-only access to collection + dashboard endpoints.
  # In `dev`, add a second rule opening the collection to public access
  # for integration tests run from laptops / CI runners. This exactly
  # mirrors the CDK envName == "dev" branch in storage-stack.ts.
  network_policy_base = [{
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${local.collection_name}"]
      },
      {
        ResourceType = "dashboard"
        Resource     = ["collection/${local.collection_name}"]
      }
    ]
    SourceVPCEs = [var.aoss_vpc_endpoint_id]
  }]

  network_policy_dev_public = var.env == "dev" ? [{
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${local.collection_name}"]
      }
    ]
    AllowFromPublic = true
  }] : []

  network_policy_rules = concat(local.network_policy_base, local.network_policy_dev_public)
}
