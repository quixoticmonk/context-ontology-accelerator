# modules/foundation/authnz

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
| [aws_dynamodb_table.cache_invalidation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table.idempotency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table.resource_role_mappings](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table.roles](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_dynamodb_table_item.builtin_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table_item) | resource |
| [aws_dynamodb_table_item.group_role_mapping](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table_item) | resource |
| [aws_ssm_parameter.cache_invalidation_table_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.idempotency_table_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.resource_role_mappings_table_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.roles_table_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name\_prefix | Physical resource name prefix (<resource\_prefix>-<env>). DynamoDB tables are named <name\_prefix>-<logical-table-name>. | `string` | n/a | yes |
| ssm\_prefix | SSM parameter root (e.g. /coa). Runtime services read AuthNZ table metadata under this path. | `string` | n/a | yes |
| cedar\_seed\_path | Filesystem path to the directory containing Cedar policy files for built-in roles (default.cedar, global\_admin.cedar, ...). When null, built-in role seeding is skipped. In-repo default: <repo>/libs/common/src/coa\_authorization/seed. | `string` | `null` | no |
| claims\_mappings | IdP group to role claim mappings seeded into the resource-role-mappings table. Each entry grants every role in mapped\_roles to the named group at platform-global scope, mirroring the CDK SeedGroupMapping custom resources. | ```list(object({ group_value = string mapped_roles = list(string) }))``` | `[]` | no |
| component | Component tag applied to every resource in this module. | `string` | `"foundation"` | no |
| environment | Deployment environment name. When set to prod, DynamoDB deletion protection is enabled on all tables (mirrors the CDK RETAIN removal policy in prod). | `string` | `"dev"` | no |

## Outputs

| Name | Description |
|------|-------------|
| cache\_invalidation\_table\_arn | ARN of the cache-invalidation table. |
| cache\_invalidation\_table\_name | Name of the cache-invalidation table. |
| cache\_invalidation\_table\_stream\_arn | DynamoDB stream ARN of the cache-invalidation table. Null — the cache-invalidation table has no stream (matches the CDK). |
| idempotency\_table\_arn | ARN of the idempotency-record table (clientToken retry records). |
| idempotency\_table\_name | Name of the idempotency-record table (clientToken retry records). |
| resource\_role\_mappings\_table\_arn | ARN of the resource-role-mappings table. |
| resource\_role\_mappings\_table\_name | Name of the resource-role-mappings table. |
| resource\_role\_mappings\_table\_stream\_arn | DynamoDB stream ARN of the resource-role-mappings table (NEW\_AND\_OLD\_IMAGES). |
| roles\_table\_arn | ARN of the roles table. |
| roles\_table\_name | Name of the roles table. |
| roles\_table\_stream\_arn | DynamoDB stream ARN of the roles table (NEW\_AND\_OLD\_IMAGES). |
<!-- END_TF_DOCS -->
