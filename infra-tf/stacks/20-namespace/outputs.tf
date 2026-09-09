# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "datazone_domain_id" {
  value = module.namespace.domain_id
}

output "namespaces_table_name" {
  value = module.namespace.namespaces_table_name
}

output "namespace_deletion_state_machine_arn" {
  value = module.namespace.namespace_deletion_state_machine_arn
}

output "smus_login_role_arn" {
  value = module.namespace.login_role_arn
}
