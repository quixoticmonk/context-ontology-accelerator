# modules/services/ontology

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
| [aws_cloudwatch_log_group.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_dynamodb_table.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_policy.api_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.idempotency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.api_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.api_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.api_proxy_idempotency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.api_proxy_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.api_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_opensearchserverless_access_policy.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_access_policy) | resource |
| [aws_service_discovery_service.ontology_engine](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_service) | resource |
| [aws_ssm_parameter.api_fn_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.cluster_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.service_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.service_namespace_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.table_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_security_group_ingress_rule.ecs_from_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| allowed\_origin | CORS allowed origin for the API proxy Lambda (e.g. https://app.example.com). | `string` | n/a | yes |
| aoss\_security\_group\_id | AOSS VPC endpoint security group ID (from network module). The ECS task reaches AOSS over HTTPS through this endpoint. | `string` | n/a | yes |
| bedrock\_chat\_model\_id | Bedrock chat/completion model ID (shared BedrockClient default — constraint inference, nl\_generator). Injected as BEDROCK\_CHAT\_MODEL\_ID. | `string` | n/a | yes |
| bedrock\_embed\_model\_id | Bedrock embedding model ID (e.g. us.cohere.embed-v4:0). Injected as BEDROCK\_EMBED\_MODEL\_ID. | `string` | n/a | yes |
| bedrock\_induction\_llm\_model\_id | Bedrock LLM model ID for ontology induction and description generation. Injected as LLM\_MODEL\_ID / DESCRIPTION\_LLM\_MODEL\_ID. Grounding rerank no longer uses this — it has its own `bedrock_grounding_llm_model_id`. | `string` | n/a | yes |
| ecr\_repository\_url | ECR repository URL for the ontology-engine image (created by stack 25-ecr). | `string` | n/a | yes |
| ecs\_security\_group\_id | ECS Fargate task security group ID (from network module). | `string` | n/a | yes |
| idempotency\_table\_arn | ARN of the shared idempotency-record DynamoDB table (from 10-foundation SSM /authnz/idempotency-table-arn). Create-operation Lambdas get Get/Put/Update/DeleteItem on it only. | `string` | n/a | yes |
| idempotency\_table\_name | Name of the shared idempotency-record DynamoDB table (from 10-foundation SSM /authnz/idempotency-table-name). Injected as IDEMPOTENCY\_TABLE for coa\_common.idempotency. | `string` | n/a | yes |
| lambda\_security\_group\_id | Lambda security group ID (from network module) for the API proxy Lambda's VPC config. | `string` | n/a | yes |
| logs\_kms\_key\_arn | CMK ARN for CloudWatch Logs encryption (from modules/foundation/kms, published to <ssm\_prefix>/kms/logs-key-arn). Applied to every aws\_cloudwatch\_log\_group in this module. | `string` | n/a | yes |
| name\_prefix | Physical resource name prefix (<resource\_prefix>-<env>). | `string` | n/a | yes |
| namespaces\_table\_name | Namespaces DDB table name (from namespace module). The task role gets read access so the catalog reader can look up dataZoneProjectId per namespace. | `string` | n/a | yes |
| neptune\_cluster\_arn | Neptune cluster resource ARN including the trailing /* (from storage module). Used verbatim for neptune-db:* data-access grants — do NOT append another suffix. | `string` | n/a | yes |
| neptune\_endpoint | Neptune cluster endpoint hostname (no scheme/port). Injected as NDB\_ENDPOINT (https://<endpoint>:8182). | `string` | n/a | yes |
| ontology\_api\_zip\_path | Path to the built API proxy Lambda zip (produced by lambdas/ontology-api/Makefile). | `string` | n/a | yes |
| ontology\_bucket\_arn | Ontology artifacts S3 bucket ARN (from storage module). Task role gets read+write for Turtle/R2RML artifacts of accepted proposals. | `string` | n/a | yes |
| ontology\_bucket\_name | Ontology artifacts S3 bucket name (from storage module). Injected as ONTOLOGY\_ARTIFACTS\_BUCKET. | `string` | n/a | yes |
| opensearch\_collection\_arn | AOSS collection ARN (from storage module). Scopes the aoss:APIAccessAll grant. | `string` | n/a | yes |
| opensearch\_collection\_name | AOSS collection name (from storage module). Injected as OSS\_INDEX and used to scope the AOSS data-access policy. | `string` | n/a | yes |
| opensearch\_endpoint | AOSS collection endpoint (from storage module). Injected as OSS\_ENDPOINT. | `string` | n/a | yes |
| private\_subnet\_ids | Private subnet IDs (from network module) for the ECS service and API proxy Lambda. | `list(string)` | n/a | yes |
| region | AWS region. | `string` | n/a | yes |
| service\_namespace\_id | Cloud Map private DNS namespace ID (from network module). The ontology-engine service registers a discovery service under it. | `string` | n/a | yes |
| service\_namespace\_name | Cloud Map private DNS namespace name (e.g. coa-dev-services.local). Used to build the ontology-engine FQDN endpoint. | `string` | n/a | yes |
| smus\_domain\_id | DataZone (SMUS) domain ID (from namespace module). Required — scopes the task role's DataZone grants to a single domain; CDK fails at synth without it. | `string` | n/a | yes |
| smus\_project\_access\_role\_arn | DataZone project-access role ARN (from namespace module). The task role assumes it before DataZone Search/GetAsset (project membership gates reads, not IAM alone). | `string` | n/a | yes |
| sources\_table\_name | Unified sources DDB table name (from sources module). Task role gets read access so the catalog reader can verify a sourceId is registered. Injected as SOURCES\_TABLE / DATASOURCES\_TABLE. | `string` | n/a | yes |
| ssm\_prefix | SSM parameter root (e.g. /coa). | `string` | n/a | yes |
| vpc\_id | VPC ID (from network module) for the API proxy Lambda placement. | `string` | n/a | yes |
| bedrock\_embed\_dimensions | Embedding vector dimensions for the configured Bedrock embed model. Injected as OSS\_DIMENSIONS / BEDROCK\_EMBED\_DIMENSIONS. | `number` | `1024` | no |
| bedrock\_grounding\_llm\_model\_id | Bedrock LLM model ID for the ontology-engine grounding reranker (GROUNDING\_LLM\_MODEL\_ID). Grounding reranks concept candidates — a cheap, high-volume call — so it defaults to the chat model (Haiku-class) rather than the heavier induction model. Set a region-valid profile here to override on a non-US deploy (GH #236). Accepts geo inference profiles and bare in-region IDs. When null, falls back to `bedrock_chat_model_id`. | `string` | `null` | no |
| component | Component tag applied to every resource in this module. | `string` | `"ontology"` | no |
| container\_port | Port the ontology-engine FastAPI container listens on. | `number` | `8001` | no |
| cpu | Fargate task CPU units (1024 = 1 vCPU). | `number` | `1024` | no |
| desired\_count | Number of ontology-engine tasks to run. | `number` | `1` | no |
| image\_tag\_file | Path to artifacts/images/ontology-engine.tag (written by the image Makefile). When null, the image URI falls back to <ecr\_repository\_url>:latest. | `string` | `null` | no |
| memory\_limit\_mib | Fargate task memory in MiB. | `number` | `2048` | no |
| oops\_endpoint | Optional OoPS! (Ontology Pitfall Scanner) endpoint for Tier-3 validation. The validator sends the serialised ontology to this URL, so it is opt-in: when empty, the OOPS\_ENDPOINT env var is omitted and the validator makes no request. HTTPS required — the scan POSTs the whole ontology. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| api\_fn\_arn | API proxy Lambda ARN (forwards API Gateway → ontology-engine via Cloud Map DNS). |
| cluster\_arn | ECS cluster ARN hosting the ontology-engine service. |
| cluster\_name | ECS cluster name hosting the ontology-engine service. |
| endpoint | Ontology Engine internal endpoint via Cloud Map DNS (http://ontology-engine.<namespace>:<port>). |
| ontology\_engine\_table\_arn | Ontology Engine DynamoDB table ARN. |
| ontology\_engine\_table\_name | Ontology Engine DynamoDB table name. |
| service\_arn | ECS Fargate service ARN for the ontology-engine. |
| service\_name | ECS Fargate service name for the ontology-engine. |
| task\_definition\_family | ECS task definition family for the ontology-engine. |
<!-- END_TF_DOCS -->
