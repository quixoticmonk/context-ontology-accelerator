# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Two DDB tables — sources (with 3 GSIs) and source-scan-jobs (with 1
# GSI). Both PAY_PER_REQUEST, AWS-managed encryption, PITR enabled.
# Match the CDK DynamoDBTable construct output exactly.

# ═════════════════════════════════════════════════════════════════════
#  sources
# ═════════════════════════════════════════════════════════════════════
# PK = NS#{namespaceId}, SK = SRC#{sourceId}
# GSIs:
#   ByNamespace     (namespaceId + createdAt,             ALL)
#   BySourceType    (namespaceId + sourceTypeCreatedAt,   ALL)
#   ByName          (namespaceId + name,                  KEYS_ONLY)
#     — O(1) name-uniqueness check on source creation
resource "aws_dynamodb_table" "sources" {
  name         = local.sources_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  deletion_protection_enabled = local.is_prod

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "namespaceId"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  attribute {
    name = "sourceTypeCreatedAt"
    type = "S"
  }

  attribute {
    name = "name"
    type = "S"
  }

  global_secondary_index {
    name            = "ByNamespace"
    hash_key        = "namespaceId"
    range_key       = "createdAt"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "BySourceType"
    hash_key        = "namespaceId"
    range_key       = "sourceTypeCreatedAt"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "ByName"
    hash_key        = "namespaceId"
    range_key       = "name"
    projection_type = "KEYS_ONLY"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  source-scan-jobs
# ═════════════════════════════════════════════════════════════════════
# PK = SRC#{sourceId}, SK = createdAt (ISO timestamp)
# GSI ByNamespace (namespaceId, ALL projection).
resource "aws_dynamodb_table" "source_scan_jobs" {
  name         = local.source_scan_jobs_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  deletion_protection_enabled = local.is_prod

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "namespaceId"
    type = "S"
  }

  global_secondary_index {
    name            = "ByNamespace"
    hash_key        = "namespaceId"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = local.tags
}
