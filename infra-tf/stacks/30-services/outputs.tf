# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "metric_service_api_fn_arn" {
  value = module.metric_service.api_fn_arn
}

output "ontology_engine_endpoint" {
  value     = module.ontology.endpoint
  sensitive = true
}

output "vkg_cluster_arn" {
  value = module.vkg.cluster_arn
}

