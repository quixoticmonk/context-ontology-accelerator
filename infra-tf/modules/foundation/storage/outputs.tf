# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "athena_results_bucket_arn" {
  description = "ARN of the Athena query results bucket."
  value       = aws_s3_bucket.athena_results.arn
}

output "athena_results_bucket_name" {
  description = "Name of the Athena query results bucket."
  value       = aws_s3_bucket.athena_results.bucket
}

output "athena_spill_bucket_arn" {
  description = "ARN of the Athena federated connector spill bucket."
  value       = aws_s3_bucket.athena_spill.arn
}

output "athena_spill_bucket_name" {
  description = "Name of the Athena federated connector spill bucket."
  value       = aws_s3_bucket.athena_spill.bucket
}

output "neptune_cluster_arn" {
  description = "Neptune data-access ARN built from the cluster resource ID (for IAM policies)."
  value       = local.neptune_cluster_arn
}

output "neptune_cluster_endpoint" {
  description = "Neptune cluster writer endpoint (host reachable from the VPC)."
  value       = aws_neptune_cluster.this.endpoint
}

output "neptune_cluster_identifier" {
  description = "Neptune cluster identifier."
  value       = aws_neptune_cluster.this.cluster_identifier
}

output "neptune_port" {
  description = "Neptune Gremlin/SPARQL port."
  value       = 8182
}

output "ontology_artifacts_bucket_arn" {
  description = "ARN of the ontology artifacts bucket."
  value       = aws_s3_bucket.ontology_artifacts.arn
}

output "ontology_artifacts_bucket_name" {
  description = "Name of the ontology artifacts bucket."
  value       = aws_s3_bucket.ontology_artifacts.bucket
}

output "opensearch_collection_arn" {
  description = "OpenSearch Serverless collection ARN (for IAM policies)."
  value       = aws_opensearchserverless_collection.this.arn
}

output "opensearch_collection_endpoint" {
  description = "OpenSearch Serverless collection endpoint."
  value       = aws_opensearchserverless_collection.this.collection_endpoint
}

output "opensearch_collection_name" {
  description = "OpenSearch Serverless collection name."
  value       = aws_opensearchserverless_collection.this.name
}
