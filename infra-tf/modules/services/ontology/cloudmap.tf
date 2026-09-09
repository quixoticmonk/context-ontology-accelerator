# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Cloud Map service discovery. The private DNS namespace is created by the
# network module; this module registers the ontology-engine discovery
# service under it. ECS wires task IPs into A records via the service's
# service_registries block (ecs.tf).

# Look up the shared namespace to recover its ARN (republished to SSM to
# keep the network export consumed across the SC → Cloud Map migration).
data "aws_service_discovery_dns_namespace" "this" {
  name = var.service_namespace_name
  type = "DNS_PRIVATE"
}

# ── Discovery service: ontology-engine.<namespace> ──────────────────
# A records, 10s TTL. Matches CDK cloudMapOptions: name "ontology-engine",
# DnsRecordType.A, dnsTtl 10s. routing_policy MULTIVALUE is the Cloud Map
# default for multiple A records behind one name (what ECS registers).
resource "aws_service_discovery_service" "ontology_engine" {
  name = "ontology-engine"

  dns_config {
    namespace_id = var.service_namespace_id

    dns_records {
      type = "A"
      ttl  = 10
    }

    routing_policy = "MULTIVALUE"
  }

  # ECS manages task registration/deregistration health via the container
  # health check. AWS pins failure_threshold to 1 and the provider deprecated
  # the argument, so the block is declared empty to opt into custom health.
  health_check_custom_config {}

  tags = local.tags
}
