# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Storage foundation: Neptune graph database (neptune.tf), OpenSearch
# Serverless vector store (opensearch.tf), Athena + ontology S3 buckets
# (s3.tf), and the SSM parameters that publish their coordinates to
# runtime consumers (below).

data "aws_caller_identity" "this" {}

# ── SSM parameters ─────────────────────────────────────────────────
# Mirror the CDK ssm.StringParameter writes so runtime services and the
# destroy scripts read storage coordinates from a stable path.

resource "aws_ssm_parameter" "opensearch_endpoint" {
  name        = "${var.ssm_prefix}/opensearch/endpoint"
  description = "OpenSearch Serverless collection endpoint"
  type        = "String"
  value       = aws_opensearchserverless_collection.this.collection_endpoint

  tags = { Component = var.component }
}

resource "aws_ssm_parameter" "opensearch_collection_name" {
  name        = "${var.ssm_prefix}/opensearch/collection-name"
  description = "OpenSearch Serverless collection name"
  type        = "String"
  value       = aws_opensearchserverless_collection.this.name

  tags = { Component = var.component }
}

resource "aws_ssm_parameter" "opensearch_collection_arn" {
  name        = "${var.ssm_prefix}/opensearch/collection-arn"
  description = "OpenSearch Serverless collection ARN"
  type        = "String"
  value       = aws_opensearchserverless_collection.this.arn

  tags = { Component = var.component }
}

resource "aws_ssm_parameter" "athena_results_bucket" {
  name        = "${var.ssm_prefix}/query/athena-results-bucket"
  description = "Athena query results S3 bucket name"
  type        = "String"
  value       = aws_s3_bucket.athena_results.bucket

  tags = { Component = var.component }
}

resource "aws_ssm_parameter" "athena_spill_bucket" {
  name        = "${var.ssm_prefix}/query/athena-spill-bucket"
  description = "Athena federated connector spill S3 bucket name"
  type        = "String"
  value       = aws_s3_bucket.athena_spill.bucket

  tags = { Component = var.component }
}

resource "aws_ssm_parameter" "ontology_bucket_name" {
  name        = "${var.ssm_prefix}/storage/ontology-bucket-name"
  description = "Ontology artifacts S3 bucket name"
  type        = "String"
  value       = aws_s3_bucket.ontology_artifacts.bucket

  tags = { Component = var.component }
}

resource "aws_ssm_parameter" "neptune_endpoint" {
  name        = "${var.ssm_prefix}/storage/neptune-endpoint"
  description = "Neptune cluster writer endpoint"
  type        = "String"
  value       = aws_neptune_cluster.this.endpoint

  tags = { Component = var.component }
}

resource "aws_ssm_parameter" "neptune_cluster_arn" {
  name        = "${var.ssm_prefix}/storage/neptune-cluster-arn"
  description = "Neptune cluster data-access ARN (uses cluster resource ID)"
  type        = "String"
  value       = local.neptune_cluster_arn

  tags = { Component = var.component }
}
