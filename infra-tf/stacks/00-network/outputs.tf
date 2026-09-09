# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "vpc_id" {
  value = module.network.vpc_id
}

output "private_subnet_ids" {
  value = module.network.private_subnet_ids
}

output "service_namespace_name" {
  value = module.network.service_namespace_name
}

output "service_namespace_id" {
  value = module.network.service_namespace_id
}
