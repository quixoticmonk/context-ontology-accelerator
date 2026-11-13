# modules/services/serve

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
| [aws_bedrockagentcore_agent_runtime.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_agent_runtime) | resource |
| [aws_bedrockagentcore_memory.session](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_memory) | resource |
| [aws_dynamodb_table.session_metadata](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_policy.aoss_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.aoss_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.runtime](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.runtime](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.aoss_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.aoss_proxy_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.aoss_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_opensearchserverless_access_policy.aoss_proxy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_access_policy) | resource |
| [aws_opensearchserverless_access_policy.serve_runtime](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_access_policy) | resource |
| [aws_security_group.agentcore](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.aoss_proxy_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.runtime_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.runtime_role_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_security_group_egress_rule.agentcore_https_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.agentcore_https_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.agentcore_jdbc_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.agentcore_neptune](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.agentcore_vkg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.aoss_from_agentcore](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| aoss\_proxy\_zip\_path | Path to the built AOSS search proxy Lambda zip. | `string` | n/a | yes |
| aoss\_security\_group\_id | AOSS VPC endpoint security group ID (from network). The AgentCore SG needs an ingress rule allowing HTTPS from the AgentCore SG here. | `string` | n/a | yes |
| aoss\_vpc\_endpoint\_id | AOSS data-plane VPC endpoint ID (from network). | `string` | n/a | yes |
| athena\_results\_bucket\_name | Athena query results bucket (from storage). Runtime writes results here. | `string` | n/a | yes |
| athena\_spill\_bucket\_name | Athena federation spill bucket (from storage). Runtime reads spilled connector results here. | `string` | n/a | yes |
| connector\_spill\_kms\_tag\_key | KMS key tag key (e.g. `coa:connector-spill`) required on a connector's spill-bucket SSE-KMS key. Scopes the kms:Decrypt grant. | `string` | n/a | yes |
| connector\_tag\_key | Lambda tag key (e.g. `coa:connector`) required on a federated connector Lambda. Scopes the AthenaFederationConnectorInvoke Allow AND the same-tag DenyAthenaInvokeOfUntaggedFunctions. | `string` | n/a | yes |
| ecr\_repository\_arn | ECR repository ARN for the Context Manager image (from stack 25-ecr). Used to scope the runtime role's image-pull grant. | `string` | n/a | yes |
| ecr\_repository\_url | ECR repository URL for the Context Manager image (from stack 25-ecr). | `string` | n/a | yes |
| issuer\_url | OIDC issuer URL. Used to build the JWT authorizer discovery URL. | `string` | n/a | yes |
| lambda\_security\_group\_id | Lambda security group ID for the AOSS proxy Lambda. | `string` | n/a | yes |
| mcp\_client\_id | MCP OAuth client ID. Included in the JWT authorizer's allowed\_audience. | `string` | n/a | yes |
| name\_prefix | <resource\_prefix>-<env>. | `string` | n/a | yes |
| namespace\_tag\_key | The `{prefix}:namespace` tag key. Used in the Null condition on the ReadPlatformSecrets statement so platform secrets (untagged) are readable by identity while namespace-bound credential secrets stay gated by their resource policies. | `string` | n/a | yes |
| namespaces\_table\_arn | Namespaces DDB table ARN (from namespace). | `string` | n/a | yes |
| namespaces\_table\_name | Namespaces DDB table name. | `string` | n/a | yes |
| neptune\_cluster\_arn | Neptune cluster ARN with the trailing /*. | `string` | n/a | yes |
| neptune\_endpoint | Neptune cluster endpoint. | `string` | n/a | yes |
| ontology\_bucket\_arn | Ontology artifacts bucket ARN. | `string` | n/a | yes |
| opensearch\_collection\_arn | AOSS collection ARN. | `string` | n/a | yes |
| opensearch\_collection\_name | AOSS collection name. | `string` | n/a | yes |
| opensearch\_endpoint | AOSS collection endpoint. | `string` | n/a | yes |
| private\_subnet\_ids | Private subnet IDs. | `list(string)` | n/a | yes |
| region | AWS region. | `string` | n/a | yes |
| resource\_prefix | Bare resource prefix (e.g. `coa`) without the env suffix. Used for the sanitized federated catalog prefix + S3 bucket prefix ARN scoping. | `string` | n/a | yes |
| resource\_role\_mappings\_table\_arn | Resource role mappings DDB table ARN. | `string` | n/a | yes |
| resource\_role\_mappings\_table\_name | Resource role mappings DDB table name. | `string` | n/a | yes |
| roles\_table\_arn | Roles DDB table ARN. | `string` | n/a | yes |
| roles\_table\_name | Roles DDB table name. | `string` | n/a | yes |
| sources\_table\_name | Sources DDB table name (from sources, by convention). | `string` | n/a | yes |
| ssm\_prefix | SSM parameter root. | `string` | n/a | yes |
| userpool\_client\_id | Web app OAuth client ID (Cognito user pool client). Included in the JWT authorizer's allowed\_audience. | `string` | n/a | yes |
| vpc\_cidr | VPC CIDR for the AgentCore SG egress rule. | `string` | n/a | yes |
| vpc\_id | VPC ID. | `string` | n/a | yes |
| agentcore\_az\_names | Defensive filter for AgentCore-supported AZs. When set, only subnets whose AZ is in this list are handed to the Runtime. | `list(string)` | `null` | no |
| allowed\_override\_models | Bedrock model IDs allowed for per-request override via options.modelId. Empty means any valid model ID is accepted. | `list(string)` | `[]` | no |
| bedrock\_embed\_model\_id | Bedrock embedding model ID (must match what doc-kg-build ingested with). | `string` | `"us.cohere.embed-v4:0"` | no |
| bedrock\_llm\_model\_id | Bedrock LLM model ID for query resolution. | `string` | `"us.anthropic.claude-sonnet-5"` | no |
| brand\_env | GRAPH\_BASE\_URI + EVENT\_SOURCE\_PREFIX to inject into the runtime environment. | `map(string)` | `{}` | no |
| component | Component tag. | `string` | `"serve"` | no |
| connector\_spill\_key\_glob | Key prefix under which every federated connector spills. Used as the resource pattern in the AthenaFederationSpillRead statement AND as the s3:prefix in ListBucket. `connectors/*/spills/*`. | `string` | `"connectors/*/spills/*"` | no |
| connector\_spill\_kms\_tag\_value | KMS key tag value (e.g. `true`). | `string` | `"true"` | no |
| connector\_tag\_value | Lambda tag value (e.g. `true`). | `string` | `"true"` | no |
| deep\_reasoning\_ontology\_timeout\_s | DEEP\_REASONING\_ONTOLOGY\_TIMEOUT\_S: fast-fail cap (seconds) on one graph-backed ontology lookup in Deep Reasoning. Must be positive and below DEEP\_REASONING\_PER\_TOOL\_TIMEOUT\_S (45). Default 6. | `number` | `6` | no |
| deep\_reasoning\_progress\_similarity\_threshold | DEEP\_REASONING\_PROGRESS\_SIMILARITY\_THRESHOLD (0.0–1.0). The loop stops once deep\_reasoning\_stability\_steps compared working answers in a row reach this cosine similarity. 0 (default) = off; typical values 0.9–0.97. | `number` | `0` | no |
| deep\_reasoning\_stability\_steps | DEEP\_REASONING\_STABILITY\_STEPS (1–20, default 2). Compared working answers in a row that must reach the similarity threshold. | `number` | `2` | no |
| deep\_reasoning\_stop\_telemetry | DEEP\_REASONING\_STOP\_TELEMETRY. true records per-reply stop\_signals traces (one extra Bedrock embed call per compared reply) without stopping the loop. Default false. | `bool` | `false` | no |
| deep\_reasoning\_sufficiency\_min\_confidence | DEEP\_REASONING\_SUFFICIENCY\_MIN\_CONFIDENCE (0.0–1.0). A "sufficient" verdict ends retrieval only at or above this model confidence. 0 (default) = off: the verdict alone decides. | `number` | `0` | no |
| env | Deployment environment name. | `string` | `"dev"` | no |
| group\_claim\_name | JWT claim name carrying group membership. | `string` | `"cognito:groups"` | no |
| image\_tag\_file | Path to artifacts/images/context-manager.tag containing the pushed ECR image URI. Null falls back to `<ecr_repo>:latest`. | `string` | `null` | no |
| neptune\_timeout\_s | NEPTUNE\_TIMEOUT: read timeout (seconds) of serve's Neptune graph client, applied to every query through it. Must be positive. Default 8. | `number` | `8` | no |
| serve\_deep\_reasoning\_default\_options | Pin DEEP\_REASONING\_DEFAULT\_OPTIONS. null (default) → env var not emitted, the recommended Deep Reasoning option set applies to options a request leaves unset. "off" (or false/0/no) puts every option back to off — the only switch for REST callers, whose Query carries no per-request options. | `string` | `null` | no |
| serve\_nl2sql\_graph\_expand | Pin SERVE\_NL2SQL\_GRAPH\_EXPAND on the serve runtime. null (default) → env var not emitted, runtime default applies (upstream: ON). Set `false` to turn off FK-hop expansion of the retrieved tables for the flat NL→SQL path on this deployment. | `bool` | `null` | no |
| serve\_nl2sql\_graph\_expand\_max\_tables | Pin SERVE\_NL2SQL\_GRAPH\_EXPAND\_MAX\_TABLES. null (default) → runtime default (8) applies. Budget for walked tables appended to the flat NL→SQL schema context; raise when the missing join table is plausibly further down the FK ordering. | `number` | `null` | no |
| serve\_vkg\_translation\_timeout\_s | Pin SERVE\_VKG\_TRANSLATION\_TIMEOUT\_S. null (default) → runtime default (60s) applies. Whole-translation budget for the NL→SPARQL route (T-Box build, LLM call, validation, retries). Raise on wide namespaces where translation p90 approaches 60s. Clamped 10..600 by the runtime. | `number` | `null` | no |
| vkg\_endpoint | VKG service endpoint (Cloud Map DNS URL for the SPARQL translator). | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| agent\_runtime\_arn | AgentCore Runtime ARN for the Context Manager. |
| agent\_runtime\_id | AgentCore Runtime ID. |
| agent\_runtime\_name | AgentCore Runtime name (underscores; hyphens replaced). |
| agentcore\_security\_group\_id | Security group attached to AgentCore Runtime ENIs. |
| aoss\_proxy\_fn\_arn | AOSS search proxy Lambda ARN (shared with MCP stack). |
| runtime\_role\_arn | AgentCore Runtime IAM role ARN (consumer query principal). |
<!-- END_TF_DOCS -->
