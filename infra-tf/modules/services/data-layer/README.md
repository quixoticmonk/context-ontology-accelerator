# modules/services/data-layer

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
| [aws_iam_policy.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.api_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_ssm_parameter.api_fn_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| data\_layer\_zip\_path | Absolute path to the built data-layer Lambda zip. Produced by modules/services/data-layer/lambdas/data-layer/Makefile. | `string` | n/a | yes |
| lambda\_security\_group\_id | Lambda security group ID (from network module). | `string` | n/a | yes |
| name\_prefix | Physical resource name prefix (resource\_prefix-env). | `string` | n/a | yes |
| namespaces\_table\_name | Namespaces DDB table name (from namespace module). | `string` | n/a | yes |
| private\_subnet\_ids | Private subnet IDs (from network module) for Lambda VPC config. | `list(string)` | n/a | yes |
| region | AWS region. | `string` | n/a | yes |
| ssm\_prefix | SSM parameter root (e.g. /coa). | `string` | n/a | yes |
| vpc\_id | VPC ID (from network module) for Lambda placement. | `string` | n/a | yes |
| allowed\_origin | CORS allowed origin for the data-layer API Lambda. | `string` | `"*"` | no |
| component | Component tag applied to every resource in this module. | `string` | `"data-layer"` | no |
| ontology\_engine\_api\_fn\_arn | Ontology-engine api-proxy Lambda ARN (from ontology module). Data-layer proxies schema queries straight through to it, bypassing the Context Manager. Null skips both the env var and the invoke grant. | `string` | `null` | no |
| serve\_runtime\_arn | AgentCore Runtime ARN (from serve module). Data-layer invokes it via bedrock-agentcore InvokeAgentRuntime for query/translate/kb/graph requests. Null skips both the env var and the invoke grant. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| api\_fn\_arn | Data Layer API Lambda function ARN. |
| api\_fn\_name | Data Layer API Lambda function name. |
<!-- END_TF_DOCS -->
