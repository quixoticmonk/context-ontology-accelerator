# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "data_layer_api_fn_arn" {
  description = "Data-layer API Lambda ARN (consumed by 60-api-edge via SSM)."
  value       = module.data_layer.api_fn_arn
}
