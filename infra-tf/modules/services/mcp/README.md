# modules/services/mcp

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
| [aws_iam_policy.ddb_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.ecr_auth_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.ecr_image_pull](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.invoke_agent_runtime](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.lambda_invoke_discovery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.ssm_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.mcp_runtime](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.ddb_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecr_auth_token](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecr_image_pull](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.invoke_agent_runtime](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.lambda_invoke_discovery](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ssm_read](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_security_group.mcp](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.runtime_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.runtime_role_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_vpc_security_group_egress_rule.https_public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.https_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cm\_runtime\_arn | Context Manager AgentCore Runtime ARN (from the serve module). Execution tools forward to it via the AgentCore invocations API; injected as CM\_RUNTIME\_ARN. | `string` | n/a | yes |
| ecr\_repository\_arn | ECR repository ARN for the MCP server image (from stack 25-ecr). Used to scope the runtime role's image-pull grant. | `string` | n/a | yes |
| ecr\_repository\_url | ECR repository URL for the MCP server image (from stack 25-ecr). | `string` | n/a | yes |
| issuer\_url | OIDC issuer URL (Cognito or external IdP). The JWT authorizer discovery URL is built as <issuer\_url>/.well-known/openid-configuration; also injected as JWT\_ISSUER\_URL. | `string` | n/a | yes |
| mcp\_client\_id | MCP CLI OAuth client ID (from auth-idp). Second entry in the JWT authorizer allowed\_audience and injected as JWT\_CLIENT\_ID (MCP callers authenticate as the CLI client). | `string` | n/a | yes |
| metric\_service\_lambda\_arn | Metric Service API Lambda ARN (from the metric\_service module). Granted lambda:InvokeFunction for the discovery tools and injected as METRIC\_SERVICE\_LAMBDA\_ARN. | `string` | n/a | yes |
| name\_prefix | Physical resource name prefix (<resource\_prefix>-<env>). | `string` | n/a | yes |
| ontology\_proxy\_lambda\_arn | Ontology Engine API proxy Lambda ARN (from the ontology module). Granted lambda:InvokeFunction for the discovery tools and injected as ONTOLOGY\_PROXY\_LAMBDA\_ARN. | `string` | n/a | yes |
| private\_subnet\_ids | Private subnet IDs (from the network module) for AgentCore Runtime ENIs. Filtered by agentcore\_az\_names when that variable is set. | `list(string)` | n/a | yes |
| region | AWS region. | `string` | n/a | yes |
| resource\_role\_mappings\_table\_arn | Resource-role-mappings DDB table ARN (from the authnz module). The runtime role gets read access (plus its index/*) for the MCP grant resolver. | `string` | n/a | yes |
| resource\_role\_mappings\_table\_name | Resource-role-mappings DDB table name (from the authnz module). Injected as RRM\_TABLE\_NAME. | `string` | n/a | yes |
| roles\_table\_arn | Roles DDB table ARN (from the authnz module). The runtime role gets read access for the MCP grant resolver. | `string` | n/a | yes |
| roles\_table\_name | Roles DDB table name (from the authnz module). Injected as ROLES\_TABLE\_NAME. | `string` | n/a | yes |
| ssm\_prefix | SSM parameter root (e.g. /coa). Used for SSM parameter writes and to scope the runtime role's ssm:GetParameter grant. | `string` | n/a | yes |
| userpool\_client\_id | Web app OAuth client ID (from auth-idp). First entry in the JWT authorizer allowed\_audience. | `string` | n/a | yes |
| vpc\_cidr | VPC CIDR block. Scopes the HTTPS egress rule to VPC endpoints (AgentCore). | `string` | n/a | yes |
| vpc\_id | VPC ID (from the network module) for the AgentCore Runtime security group. | `string` | n/a | yes |
| agentcore\_az\_names | AgentCore-supported AZ names used to filter private\_subnet\_ids down to subnets AgentCore Runtime can place ENIs in. When null, all private\_subnet\_ids are used unfiltered. | `list(string)` | `null` | no |
| brand\_env | Brand-specific environment variables (GRAPH\_BASE\_URI, EVENT\_SOURCE\_PREFIX) from the root config, merged into the runtime environment\_variables map. | `map(string)` | `{}` | no |
| component | Component tag applied to every resource in this module. | `string` | `"mcp"` | no |
| env | Deployment environment name (e.g. dev). Injected as ENVIRONMENT. | `string` | `"dev"` | no |
| group\_claim\_name | JWT claim carrying group membership (cognito:groups for Cognito, or the customer's configured OIDC claim). Injected as GROUP\_CLAIM\_NAME for group-based role resolution. | `string` | `"cognito:groups"` | no |
| image\_tag\_file | Path to artifacts/images/mcp-server.tag (written by the image Makefile) containing the pushed ECR image URI. When null, the image URI falls back to <ecr\_repository\_url>:latest. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| agent\_runtime\_arn | MCP AgentCore Runtime ARN. |
| agent\_runtime\_id | MCP AgentCore Runtime ID. |
| runtime\_role\_arn | MCP AgentCore Runtime execution IAM role ARN. |
<!-- END_TF_DOCS -->
