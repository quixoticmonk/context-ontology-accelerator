# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

output "api_fn_arn" {
  description = "Metric API Lambda function ARN."
  value       = aws_lambda_function.metric_api.arn
}

output "import_dlq_arn" {
  description = "Metric import DLQ ARN."
  value       = aws_sqs_queue.import_dlq.arn
}

output "import_jobs_table_arn" {
  description = "Import jobs DynamoDB table ARN."
  value       = aws_dynamodb_table.import_jobs.arn
}

output "import_jobs_table_name" {
  description = "Import jobs DynamoDB table name."
  value       = aws_dynamodb_table.import_jobs.name
}

output "import_queue_arn" {
  description = "Metric import SQS queue ARN."
  value       = aws_sqs_queue.import.arn
}

output "import_queue_url" {
  description = "Metric import SQS queue URL."
  value       = aws_sqs_queue.import.url
}

output "import_worker_fn_arn" {
  description = "Import worker Lambda function ARN."
  value       = aws_lambda_function.import_worker.arn
}

output "import_dlq_recovery_fn_arn" {
  description = "Import DLQ recovery Lambda function ARN. Triggered off the metric-import DLQ; deliberately out-of-VPC (see api_lambdas.tf section header)."
  value       = aws_lambda_function.import_dlq_recovery.arn
}
