# modules/services/metric-service

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.13 |
| aws | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 6.0 |

## Resources

| Name | Type |
|------|------|
| [aws_dynamodb_table.import_jobs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_policy.idempotency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.import_dlq_recovery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.import_worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.metric_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.import_dlq_recovery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.import_worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.metric_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.import_dlq_recovery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.import_dlq_recovery_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.import_worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.import_worker_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.metric_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.metric_api_idempotency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.metric_api_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_event_source_mapping.import_dlq_recovery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_event_source_mapping.import_worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_function.import_dlq_recovery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.import_worker](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.metric_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_opensearchserverless_access_policy.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_access_policy) | resource |
| [aws_s3_bucket.osi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.osi_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_cors_configuration.osi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_cors_configuration) | resource |
| [aws_s3_bucket_lifecycle_configuration.osi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.osi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_policy.osi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.osi_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.osi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.osi_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.osi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.osi_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.osi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_sqs_queue.import](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.import_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_policy.import](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_sqs_queue_policy.import_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_ssm_parameter.import_jobs_table_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.import_queue_url](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.metric_api_fn_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_security_group_ingress_rule.aoss_from_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aoss\_security\_group\_id | AOSS VPC endpoint security group ID (from network module). This module adds an ingress rule allowing the Lambda security group to reach the endpoint on 443. | `string` | n/a | yes |
| brand\_env | Brand-specific env map (GRAPH\_BASE\_URI + EVENT\_SOURCE\_PREFIX). GRAPH\_BASE\_URI feeds NDB\_GRAPH\_URI\_BASE on both Lambdas so metric writes land on the same named-graph base URI that serve reads from — the CDK DEFAULT\_GRAPH\_URI\_BASE consolidation. EVENT\_SOURCE\_PREFIX is accepted for symmetry with peer modules; metric-service does not currently emit EventBridge events. | `map(string)` | n/a | yes |
| idempotency\_table\_arn | ARN of the shared idempotency-record DynamoDB table (from 10-foundation SSM /authnz/idempotency-table-arn). Create-operation Lambdas get Get/Put/Update/DeleteItem on it only. | `string` | n/a | yes |
| idempotency\_table\_name | Name of the shared idempotency-record DynamoDB table (from 10-foundation SSM /authnz/idempotency-table-name). Injected as IDEMPOTENCY\_TABLE for coa\_common.idempotency. | `string` | n/a | yes |
| lambda\_security\_group\_id | Lambda security group ID (from network module) for the API and import worker functions. | `string` | n/a | yes |
| metric\_service\_zip\_path | Absolute path to the built metric-service Lambda zip. Produced by modules/services/metric-service/lambdas/metric-service/Makefile; both Lambdas read from this zip. | `string` | n/a | yes |
| name\_prefix | Physical resource name prefix (<resource\_prefix>-<env>). | `string` | n/a | yes |
| namespaces\_table\_name | Namespaces DDB table name (from namespace module). Read by both Lambdas for SMUS catalog validation. | `string` | n/a | yes |
| neptune\_cluster\_arn | Neptune cluster ARN for IAM scoping (from storage module). Uses cluster\_resource\_id form with a /* suffix for neptune-db data-access actions. | `string` | n/a | yes |
| neptune\_endpoint | Neptune cluster writer endpoint host (from storage module), without protocol or port. | `string` | n/a | yes |
| opensearch\_collection\_arn | AOSS collection ARN (from storage module) for the aoss:APIAccessAll IAM grant. | `string` | n/a | yes |
| opensearch\_collection\_name | AOSS collection name (from storage module). Used as the OSS index prefix env var and to scope the AOSS data-access policy. | `string` | n/a | yes |
| opensearch\_endpoint | AOSS collection endpoint (from storage module). Injected as OPENSEARCH\_ENDPOINT into both Lambdas. | `string` | n/a | yes |
| private\_subnet\_ids | Private subnet IDs (from network module) for Lambda VPC config. | `list(string)` | n/a | yes |
| region | AWS region. | `string` | n/a | yes |
| sources\_table\_name | Sources DDB table name (from sources module). Read by both Lambdas for SMUS catalog validation. Sources deploys after metric-service in dependency order, so this is taken as a plain string and resolved at plan time. | `string` | n/a | yes |
| ssm\_prefix | SSM parameter root (e.g. /coa). | `string` | n/a | yes |
| vpc\_id | VPC ID (from network module) for Lambda placement. | `string` | n/a | yes |
| allowed\_origin | CORS allowed origin for the metric API Lambda and OSI staging bucket. | `string` | `"*"` | no |
| bedrock\_embed\_model\_id | Bedrock embedding model ID for metric matching. Defaults to the us.cohere.embed-v4:0 cross-region inference profile. | `string` | `"us.cohere.embed-v4:0"` | no |
| component | Component tag applied to every resource in this module. | `string` | `"metric-service"` | no |
| event\_bus\_name | EventBridge bus name for metric lifecycle events. | `string` | `"default"` | no |
| smus\_domain\_id | SMUS (DataZone) domain ID (from namespace module). Injected as SMUS\_DOMAIN\_ID for catalog validation. Null omits the env var. | `string` | `null` | no |
| smus\_project\_access\_role\_arn | Shared DataZone project access role ARN (from namespace module). Both Lambdas assume it (sts:AssumeRole) for SMUS catalog operations. Null omits the grant and env var. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| api\_fn\_arn | Metric API Lambda function ARN. |
| import\_dlq\_arn | Metric import DLQ ARN. |
| import\_dlq\_recovery\_fn\_arn | Import DLQ recovery Lambda function ARN. Triggered off the metric-import DLQ; deliberately out-of-VPC (see api\_lambdas.tf section header). |
| import\_jobs\_table\_arn | Import jobs DynamoDB table ARN. |
| import\_jobs\_table\_name | Import jobs DynamoDB table name. |
| import\_queue\_arn | Metric import SQS queue ARN. |
| import\_queue\_url | Metric import SQS queue URL. |
| import\_worker\_fn\_arn | Import worker Lambda function ARN. |
<!-- END_TF_DOCS -->
