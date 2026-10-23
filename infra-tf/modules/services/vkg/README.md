# modules/services/vkg

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
| [aws_cloudwatch_event_rule.ontology_published](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.reload_sweep](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.ontology_published](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.reload_sweep](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.reload_failed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_policy.execution_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.reload](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.reload](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.execution_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.execution_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.reload](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.reload_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.reload](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.reload_from_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.reload_from_sweep](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_ssm_parameter.cluster_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.cluster_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.container_image](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.container_port](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.service_namespace_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.task_definition_family](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_security_group_ingress_rule.vkg_from_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| ecr\_repository\_url | ECR repository URL for the VKG image (created by stack 25-ecr). | `string` | n/a | yes |
| ecs\_security\_group\_id | ECS Fargate task security group ID (from network module). Applied to per-namespace VKG services by the reload Lambda. | `string` | n/a | yes |
| lambda\_security\_group\_id | Lambda function security group ID (from network module) for the reload Lambda VPC config. | `string` | n/a | yes |
| logs\_kms\_key\_arn | CMK ARN for CloudWatch Logs encryption (from modules/foundation/kms, published to <ssm\_prefix>/kms/logs-key-arn). Applied to every aws\_cloudwatch\_log\_group in this module. | `string` | n/a | yes |
| name\_prefix | Physical resource name prefix (<resource\_prefix>-<env>). | `string` | n/a | yes |
| ontology\_bucket\_arn | Ontology artifacts S3 bucket ARN (from storage module). The task role reads the compiled ontology and R2RML mappings from this bucket. | `string` | n/a | yes |
| ontology\_bucket\_name | Ontology artifacts S3 bucket name (from storage module). Injected into the task and reload Lambda as ONTOLOGY\_BUCKET. | `string` | n/a | yes |
| private\_subnet\_ids | Private subnet IDs (from network module) for the reload Lambda VPC config and per-namespace VKG services. | `list(string)` | n/a | yes |
| region | AWS region. | `string` | n/a | yes |
| service\_namespace\_id | Cloud Map private DNS namespace ID (from network module). The reload Lambda registers per-namespace VKG services under it. | `string` | n/a | yes |
| service\_namespace\_name | Cloud Map private DNS namespace name (e.g. coa-dev-services.local). Used to build the VKG endpoint pattern. | `string` | n/a | yes |
| ssm\_prefix | SSM parameter root (e.g. /coa). | `string` | n/a | yes |
| vkg\_reload\_zip\_path | Path to the built reload Lambda zip. Produced by modules/services/vkg/lambdas/reload/Makefile. | `string` | n/a | yes |
| vpc\_id | VPC ID (from network module) for the reload Lambda placement. | `string` | n/a | yes |
| component | Component tag applied to every resource in this module. | `string` | `"vkg"` | no |
| container\_port | Container port the Ontop SPARQL endpoint listens on. | `number` | `8080` | no |
| cpu | Fargate CPU units for the VKG task definition (1024 = 1 vCPU). | `number` | `1024` | no |
| event\_source\_prefix | EventBridge source prefix that ontology publishers emit under. The reload rule matches source <event\_source\_prefix>.ontology. Matches the emitter's EVENT\_SOURCE\_PREFIX env var. | `string` | `"coa"` | no |
| image\_tag\_file | Path to the built image tag file (artifacts/images/vkg.tag) containing the full pushed ECR image URI. Null falls back to <ecr\_repo>:latest. | `string` | `null` | no |
| lambda\_reserved\_concurrency | Reserved concurrency for the reload Lambda; bounds its blast radius since it drives serial ECS updates. 0 omits the reservation so the module deploys on reduced-quota accounts. | `number` | `5` | no |
| memory\_limit\_mib | Fargate memory in MiB for the VKG task definition. | `number` | `2048` | no |
| ontop\_java\_args | JVM args for the Ontop launcher, passed via ONTOP\_JAVA\_ARGS (NOT JAVA\_OPTS, which the launcher ignores — #149 cause C). Null derives the value from memory\_limit\_mib (max heap ~75%, initial ~25%) so scaling memory alone scales the heap. Applied to both the CDK-style task-def template here AND to the reload Lambda's per-namespace task defs so the two stay in lockstep. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| cluster\_arn | VKG ECS cluster ARN. Consumed by namespace\_api (VKG health) and the deletion pipeline. |
| cluster\_name | VKG ECS cluster name. |
| container\_port | Container port the Ontop SPARQL endpoint listens on. |
| service\_namespace\_name | Cloud Map private DNS namespace name used for per-namespace VKG service discovery. |
| task\_definition\_family | VKG task-definition template family. Per-namespace revisions are registered under a derived family at runtime. |
<!-- END_TF_DOCS -->
