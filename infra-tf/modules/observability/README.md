# modules/observability

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
| [aws_cloudwatch_metric_alarm.api_5xx](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.api_latency_p99](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.cluster_cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.cluster_memory](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.ddb_read_throttled](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.ddb_system_errors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.ddb_write_throttled](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.dlq_messages](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.fargate_cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.fargate_memory](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.lambda_faults](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.lambda_throttles](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.sfn_failed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| alarm\_name\_prefix | Prefix on every alarm name. Matches CDK `SclMonitoring.alarmNamePrefix` (typically `<resource_prefix>-<env>`). | `string` | n/a | yes |
| alarm\_topic\_arn | Optional SNS topic ARN wired to every alarm's alarm\_actions (and ok\_actions). When null the alarms are action-ready but route nowhere — this matches CDK round-one, where actionsEnabled=true but no strategy is bound yet. | `string` | `null` | no |
| component | Component tag. | `string` | `"observability"` | no |
| dlq\_arns | Set of dead-letter queue ARNs. Emits one alarm per DLQ on ApproximateNumberOfMessagesVisible > 1. Matches CDK monitorQueueWithDlq(). | `set(string)` | `[]` | no |
| dynamodb\_table\_names | Set of DynamoDB table names. Emits three alarms per table: read-throttled events, write-throttled events, and system errors > 1. Matches CDK monitorTable(). | `set(string)` | `[]` | no |
| ecs\_cluster\_only\_names | Set of ECS cluster names monitored at the cluster level (used where a stack runs an ECS cluster with runtime-created services, e.g. VKG). Emits CPU-max and Memory-avg alarms per cluster. Matches CDK monitorClusterCpuMem(). | `set(string)` | `[]` | no |
| fargate\_services | Map of alarm-friendly-name => { cluster\_name, service\_name } to monitor as ECS Fargate services. Emits CPU and Memory average alarms per service. Matches CDK monitorFargateService(). | ```map(object({ cluster_name = string service_name = string }))``` | `{}` | no |
| lambda\_names | Set of Lambda function names. Emits two alarms per Lambda: Errors > 1 and Throttles > 1. Matches CDK monitorLambda(). | `set(string)` | `[]` | no |
| rest\_api\_names | Set of REST API names (ApiName dimension in AWS/ApiGateway). Emits two alarms per API: Latency P99 > 5s and 5XXError > 1. Matches CDK monitorApi(). | `set(string)` | `[]` | no |
| state\_machine\_arns | Set of Step Functions state machine ARNs. Emits one alarm per SM on ExecutionsFailed > 1. Matches CDK monitorStateMachine(). | `set(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| alarm\_count | Total number of alarms emitted by this module. |
<!-- END_TF_DOCS -->
