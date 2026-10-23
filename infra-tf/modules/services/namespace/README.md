# modules/services/namespace

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.13 |
| aws | ~> 6.0 |
| awscc | ~> 1.100 |
| external | ~> 2.3 |
| time | ~> 0.12 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 6.0 |
| awscc | ~> 1.100 |

## Resources

| Name | Type |
|------|------|
| [aws_datazone_asset_type.coa_relational_table](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/datazone_asset_type) | resource |
| [aws_datazone_domain.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/datazone_domain) | resource |
| [aws_datazone_form_type.coa_table_metadata](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/datazone_form_type) | resource |
| [aws_datazone_policy_grant.create_asset_type](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/datazone_policy_grant) | resource |
| [aws_datazone_policy_grant.create_form_type](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/datazone_policy_grant) | resource |
| [aws_datazone_user_profile.dz_project_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/datazone_user_profile) | resource |
| [aws_datazone_user_profile.namespace_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/datazone_user_profile) | resource |
| [aws_dynamodb_table.namespaces](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_iam_policy.del_finalize](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.del_mark_failed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.del_metrics](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.del_ontology](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.del_platform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.del_sources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.dz_project_access_datazone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.grants_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.idempotency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.login_pass_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.namespace_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.platform_roles_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.roles_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.sfn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.smus_exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.del_finalize](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.del_mark_failed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.del_metrics](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.del_ontology](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.del_platform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.del_sources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.dz_project_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.grants_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.login](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.namespace_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.platform_roles_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.roles_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.sfn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.smus_exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.del_finalize](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.del_finalize_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.del_mark_failed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.del_mark_failed_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.del_metrics](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.del_metrics_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.del_ontology](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.del_ontology_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.del_platform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.del_platform_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.del_sources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.del_sources_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.dz_project_access_datazone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.grants_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.grants_api_idempotency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.grants_api_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.login_managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.login_pass_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.namespace_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.namespace_api_idempotency](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.namespace_api_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.platform_roles_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.platform_roles_api_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.roles_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.roles_api_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.sfn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.smus_exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.del_finalize](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.del_mark_failed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.del_metrics](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.del_ontology](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.del_platform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.del_sources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.grants_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.namespace_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.platform_roles_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.roles_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_opensearchserverless_access_policy.del_sources_graphrag](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/opensearchserverless_access_policy) | resource |
| [aws_sfn_state_machine.namespace_deletion](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sfn_state_machine) | resource |
| [aws_ssm_parameter.domain_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.dz_project_access_role_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.grants_api_fn_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.login_role_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.namespace_api_fn_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.namespaces_table_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.platform_roles_api_fn_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.roles_api_fn_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [awscc_datazone_owner.namespace_api_root_domain_unit](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/datazone_owner) | resource |
| [awscc_datazone_project.system](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/datazone_project) | resource |
| [awscc_datazone_project_profile.default](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/datazone_project_profile) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| control\_plane\_zip\_path | Absolute path to the built control-plane Lambda zip. Produced by modules/services/namespace/lambdas/control-plane/Makefile; every Lambda in this module reads from this zip. | `string` | n/a | yes |
| idempotency\_table\_arn | ARN of the shared idempotency-record DynamoDB table (from 10-foundation SSM /authnz/idempotency-table-arn). Create-operation Lambdas get Get/Put/Update/DeleteItem on it only. | `string` | n/a | yes |
| idempotency\_table\_name | Name of the shared idempotency-record DynamoDB table (from 10-foundation SSM /authnz/idempotency-table-name). Injected as IDEMPOTENCY\_TABLE for coa\_common.idempotency. | `string` | n/a | yes |
| lambda\_security\_group\_id | Lambda security group ID (from network module). | `string` | n/a | yes |
| name\_prefix | Physical resource name prefix (<resource\_prefix>-<env>). | `string` | n/a | yes |
| private\_subnet\_ids | Private subnet IDs (from network module) for Lambda VPC config. | `list(string)` | n/a | yes |
| region | AWS region. | `string` | n/a | yes |
| resource\_prefix | Bare resource prefix (e.g. `coa`) without the env suffix. Used for the resource-tag key that binds JDBC credential secrets to authorized namespaces (see namespaceTagKey in the CDK). | `string` | n/a | yes |
| resource\_role\_mappings\_table\_arn | Resource role mappings DDB table ARN (from authnz module). | `string` | n/a | yes |
| resource\_role\_mappings\_table\_name | Resource role mappings DDB table name (from authnz module). | `string` | n/a | yes |
| roles\_table\_arn | Roles DDB table ARN (from authnz module). | `string` | n/a | yes |
| roles\_table\_name | Roles DDB table name (from authnz module). | `string` | n/a | yes |
| ssm\_prefix | SSM parameter root (e.g. /coa). | `string` | n/a | yes |
| vpc\_id | VPC ID (from network module) for Lambda placement. | `string` | n/a | yes |
| allowed\_origin | CORS allowed origin for the four API Lambdas. | `string` | `"*"` | no |
| cache\_invalidation\_table\_name | Cache invalidation DDB table name (from authnz module). Passed through to API Lambdas for streams-based cache busting. | `string` | `null` | no |
| cloud\_map\_namespace\_id | Cloud Map private DNS namespace ID (from network module). Used by the deletion pipeline's DeletePlatform step to deregister per-namespace VKG services on teardown. Null skips the servicediscovery grants. | `string` | `null` | no |
| component | Component tag applied to every resource in this module. | `string` | `"namespace"` | no |
| ontology\_bucket\_name | Ontology artifacts S3 bucket name (from storage module). Deletion pipeline sweeps this bucket per-namespace on teardown. Null skips the S3 sweep. | `string` | `null` | no |
| ontology\_engine\_endpoint | Ontology-engine HTTP endpoint (Cloud Map DNS, e.g. http://ontology-engine.<prefix>-services.local:8001). Used by namespace\_api (preflight checks for active induction jobs) and the deletion pipeline's DeleteOntology step. Null disables both. | `string` | `null` | no |
| opensearch\_collection\_name | AOSS collection name (from storage module). Deletion pipeline drops the namespace's GraphRAG doc-KG indexes on teardown when set. | `string` | `null` | no |
| opensearch\_endpoint | AOSS collection endpoint (from storage module). Deletion pipeline requires it to drop GraphRAG indexes on teardown. | `string` | `null` | no |
| smus\_admin\_principal\_arns | IAM role/user ARNs allowed to assume the SMUS admin login role. Empty list falls back to `arn:aws:iam::<account>:role/Admin`. | `list(string)` | `[]` | no |
| smus\_require\_mfa | When true, deny assume-role on the SMUS login role unless MFA is present in the session. | `bool` | `false` | no |
| vkg\_cluster\_arn | VKG ECS cluster ARN (from vkg module). Used by namespace\_api for read-time VKG health resolution and by the deletion pipeline for per-namespace service teardown. Null disables both. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| domain\_arn | DataZone (SMUS) domain ARN. |
| domain\_id | DataZone (SMUS) domain ID. |
| dz\_project\_access\_role\_arn | Shared role assumed by service Lambdas for DataZone project operations. |
| grants\_api\_fn\_arn | Grants API Lambda ARN. |
| login\_role\_arn | SMUS admin login role ARN. Assumed via console to reach the SMUS UI. |
| namespace\_api\_fn\_arn | Namespace API Lambda ARN. Handles create + list + delete-trigger. |
| namespace\_deletion\_state\_machine\_arn | Step Functions state machine ARN for the namespace deletion pipeline. |
| namespaces\_table\_arn | Namespaces DDB table ARN. |
| namespaces\_table\_name | Namespaces DDB table name. |
| platform\_roles\_api\_fn\_arn | Platform Roles API Lambda ARN. |
| roles\_api\_fn\_arn | Roles API Lambda ARN (namespace-scoped role list/get). |
| system\_project\_id | DataZone system project ID (owns shared form and asset types). |
<!-- END_TF_DOCS -->
