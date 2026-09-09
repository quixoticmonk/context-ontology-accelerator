# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "sources_api_fn_arn" {
  value = module.sources.sources_api_fn_arn
}

output "sources_bucket_name" {
  value = module.sources.sources_bucket_name
}

output "sources_table_name" {
  value = module.sources.sources_table_name
}

output "sources_db_scan_state_machine_arn" {
  value = module.sources.db_scan_state_machine_arn
}

output "sources_doc_ingestion_state_machine_arn" {
  value = module.sources.doc_ingestion_state_machine_arn
}
