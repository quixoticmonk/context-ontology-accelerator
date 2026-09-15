# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "logs_key_arn" {
  description = "ARN of the CloudWatch Logs encryption CMK. Consumers should prefer reading this from SSM (see modules/foundation/kms/main.tf) so this module can be moved without rewiring."
  value       = aws_kms_key.logs.arn
}

output "logs_key_alias" {
  description = "Alias of the CloudWatch Logs encryption CMK."
  value       = aws_kms_alias.logs.name
}
