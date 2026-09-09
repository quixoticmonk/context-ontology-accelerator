# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# OpenSearch Serverless VECTORSEARCH collection, NEXTGEN generation.
# AOSS uses dedicated security policies (encryption + network) and
# data-access policies rather than standard IAM resource policies.
#
# NEXTGEN specifics (matches infra/lib/stacks/foundation/storage-stack.ts):
#   - `generation = "NEXTGEN"` on the collection group
#   - `standby_replicas = "ENABLED"` on both the group and the collection
#     (AWS rejects DISABLED for NEXTGEN — replicas managed internally)
#   - Capacity limits: default min 2 / max 96 OCU on both indexing and
#     search. `aoss_min_ocu = 0` enables scale-to-zero.
#   - Network policy is VPCE-scoped in every environment. `dev` gets an
#     additional AllowFromPublic rule so integration tests can run from
#     developer laptops and CI runners without a VPN.

# Encryption policy — must exist before the collection is created.
resource "aws_opensearchserverless_security_policy" "encryption" {
  name = "${var.name_prefix}-encryption"
  type = "encryption"

  policy = jsonencode({
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${local.collection_name}"]
      }
    ]
    AWSOwnedKey = true
  })
}

# Network policy — VPCE-scoped by default. `dev` gets a second rule
# opening the collection to public access for laptop / CI testing.
# Both `collection` and `dashboard` resource types are scoped to the
# platform VPC endpoint to match the CDK behavior exactly.
resource "aws_opensearchserverless_security_policy" "network" {
  name = "${var.name_prefix}-network"
  type = "network"

  policy = jsonencode(local.network_policy_rules)
}

# Data-access policy — grants collection + index CRUD to the current
# caller as a placeholder so the collection is usable during smoke
# testing. Downstream modules attach their own additive access policies
# for Neptune-notebook / Lambda / ECS roles.
resource "aws_opensearchserverless_access_policy" "data" {
  name = "${var.name_prefix}-data"
  type = "data"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection"
          Resource     = ["collection/${local.collection_name}"]
          Permission = [
            "aoss:CreateCollectionItems",
            "aoss:DeleteCollectionItems",
            "aoss:UpdateCollectionItems",
            "aoss:DescribeCollectionItems",
          ]
        },
        {
          ResourceType = "index"
          Resource     = ["index/${local.collection_name}/*"]
          Permission = [
            "aoss:CreateIndex",
            "aoss:DeleteIndex",
            "aoss:UpdateIndex",
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument",
          ]
        }
      ]
      Principal = [data.aws_caller_identity.this.arn]
    }
  ])
}

# ── NEXTGEN Collection Group ────────────────────────────────────────
# NEXTGEN provides ~2x indexing throughput and sub-100ms p99 search
# latency. Standby replicas MUST be ENABLED (AWS rejects DISABLED for
# NEXTGEN). Capacity limits cap cost at max OCU and set the floor at
# min OCU (set aoss_min_ocu = 0 for NEXTGEN scale-to-zero).
resource "aws_opensearchserverless_collection_group" "this" {
  name             = "${var.name_prefix}-vector-store-group"
  generation       = "NEXTGEN"
  standby_replicas = "ENABLED"
  description      = "SemanticContext vector store for embeddings and similarity search"

  capacity_limits = [{
    max_indexing_capacity_in_ocu = var.aoss_max_ocu
    max_search_capacity_in_ocu   = var.aoss_max_ocu
    min_indexing_capacity_in_ocu = var.aoss_min_ocu
    min_search_capacity_in_ocu   = var.aoss_min_ocu
  }]

  tags = { Component = var.component }
}

resource "aws_opensearchserverless_collection" "this" {
  name                  = local.collection_name
  type                  = "VECTORSEARCH"
  standby_replicas      = "ENABLED"
  collection_group_name = aws_opensearchserverless_collection_group.this.name
  description           = "SemanticContext vector store for embeddings and similarity search"

  tags = { Component = var.component }

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
    aws_opensearchserverless_access_policy.data,
  ]
}
