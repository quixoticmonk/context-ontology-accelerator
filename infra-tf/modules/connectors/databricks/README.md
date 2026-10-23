# modules/connectors/databricks

Terraform module for the **Databricks SQL Warehouse Athena federation connector**
— the Terraform parity to the upstream CDK app at
`connectors/databricks/cdk/`. Deploys the connector Lambda, its spill
bucket + KMS key, IAM, and publishes the function/role ARNs to SSM so a
COA deployment can discover them.

> **Standalone**. This module is NOT wired into any `infra-tf/stacks/`
> stack and NOT invoked by any Makefile target in `infra-tf/Makefile`.
> Call it from your own Terraform configuration when you need the
> connector; the main COA deploy flow does not touch it.

## When to use

The connector runs as a Lambda that Athena invokes to translate SQL into
Databricks SQL Warehouse queries. Two shapes:

| Mode | Who deploys | How to use |
|------|-------------|------------|
| `environment` (default) | Customer, in their own AWS account | Points at one workspace + warehouse + credential. The Lambda name has no `-managed-` segment. One connector per workspace. |
| `coa-managed` | The COA platform team, alongside a COA deployment | One Lambda serves every `DATABRICKS_SQL_WAREHOUSE` source in the COA environment. Per-source config comes from SSM (`/{prefix}/{env}/connectors/databricks/sources/<sourceId>`), written by the sources API. The Lambda name carries the reserved `-managed-` segment. |

## Prerequisites

- A built fat jar at a stable local path. Build it with:
  ```bash
  cd connectors/databricks
  mvn clean package
  # produces target/databricks-connector-<version>.jar
  ```
  The module reads this file at plan time and uploads it as a Lambda zip.
  Keep the jar stable (don't rebuild between `plan` and `apply`), or
  Lambda redeploys on every apply.
- Terraform ≥ 1.14 and AWS provider ~> 6.0.

## Example — customer-deployed, single endpoint

```hcl
module "databricks_connector" {
  source = "../../infra-tf/modules/connectors/databricks"

  resource_prefix = "acme"
  env             = "prod"
  jar_path        = "${path.module}/jars/databricks-connector-1.0.0.jar"

  config_source = "environment"

  databricks_workspace_host = "dbc-abcd-ef01.cloud.databricks.com"
  databricks_warehouse_id   = "0123456789abcdef"
  databricks_catalog        = "main"
  databricks_schema         = "sales"
  credential_secret_arn     = aws_secretsmanager_secret.dbx.arn
  credential_kms_key_arn    = aws_kms_key.dbx.arn   # only if the secret uses a CMK

  # Query principals from the COA deployment (read from the deployment's SSM):
  query_role_arns = [
    data.aws_ssm_parameter.coa_serve_role.value,
    data.aws_ssm_parameter.coa_discovery_role.value,
  ]

  # Optional VPC — required if the workspace is PrivateLink-only.
  vpc_id     = "vpc-0a1b2c3d4e5f60718"
  subnet_ids = ["subnet-0a1b2c3d4e5f60711", "subnet-0a1b2c3d4e5f60722"]
}
```

## Example — COA-managed, multi-source

```hcl
module "databricks_connector" {
  source = "../../infra-tf/modules/connectors/databricks"

  resource_prefix = "coa"
  env             = "dev"
  jar_path        = "${path.module}/jars/databricks-connector-1.0.0.jar"

  config_source = "coa-managed"

  query_role_arns = [
    # In managed mode the connector lives in the SAME account as COA, so
    # read the ARNs from the deployment's SSM instead of pasting them.
    data.aws_ssm_parameter.serve_role.value,
    data.aws_ssm_parameter.discovery_role.value,
  ]

  retain_spill_on_destroy = true   # prod convention
}

data "aws_ssm_parameter" "serve_role" {
  name = "/coa/dev/serve/runtime-role-arn"
}
data "aws_ssm_parameter" "discovery_role" {
  name = "/coa/dev/sources/db-connector-role-arn"
}
```

## What the module creates

- `aws_lambda_function` on Java 21 / arm64, with the fat jar zipped at
  `lib/<jar>` so Lambda's EXTRACTED-size limit measures the jar itself,
  not its contents.
- `aws_iam_role` + policies:
  - `AWSLambdaBasicExecutionRole` + `AWSLambdaVPCAccessExecutionRole`
    (when VPC-attached).
  - Spill RW + KMS `GenerateDataKey` on the module's own CMK.
  - **environment mode:** Secrets Manager `GetSecretValue` on the pinned
    `credential_secret_arn`, with `kms:Decrypt` on the pinned
    `credential_kms_key_arn` when supplied.
  - **coa-managed mode:** SSM `GetParameter*` under
    `/{prefix}/{env}/connectors/databricks/sources/*`, and Secrets Manager
    `GetSecretValue` on any secret tagged
    `{prefix}:connector-credential = databricks` in this account.
- `aws_kms_key` + alias for spill encryption, carrying the
  `{prefix}:connector-spill = true` tag so COA's `kms:Decrypt` ABAC
  condition matches it.
- `aws_s3_bucket` for spill, SSE-KMS with bucket-key-enabled, public
  access blocked, 1-day expiry (spill is scratch), TLS-only policy.
- `aws_lambda_permission` + spill `s3:GetObject` + CMK `kms:Decrypt`
  grants per entry in `query_role_arns`.
- `aws_cloudwatch_log_group` with 30-day retention (configurable).
- Optional `aws_security_group` with HTTPS-only egress, created when
  `vpc_id` is set and `security_group_ids` is null.
- `aws_ssm_parameter` × 2 publishing the function ARN and role ARN
  under `/{prefix}/{env}/connectors/databricks/deployment/`.

## Tag contract

Three tag conventions this module honours — do NOT override via
`var.tags`:

| Tag key | Applied to | Why |
|---------|------------|-----|
| `{prefix}:connector = true` | Lambda | COA's `lambda:InvokeFunction` grant matches on this tag — without it, Athena's invoke is denied on the first scan. |
| `{prefix}:connector-spill = true` | KMS key | COA's `kms:Decrypt` grant conditions on this tag — without it, spilled responses can't be decrypted and queries fail silently (empty rows). |
| `Component = databricks-connector` | all | Operator tag for filtering. |

## Spill prefix

Fixed at `connectors/databricks/spills/` (not configurable). COA's
spill-access grant globs on `connectors/*/spills/*`, which this module's
Lambda env (`spill_prefix`) uses.

## What this module intentionally does NOT do

- **No Athena data catalog registration.** The sources API creates
  Athena data catalogs per source (via `CreateDataCatalog` with
  `function=<arn>`), and the connector ARN is read from SSM. If you're
  using this module OUTSIDE a COA deployment, register the catalog with:
  ```bash
  aws athena create-data-catalog \
    --name databricks \
    --type LAMBDA \
    --parameters function=$(terraform output -raw function_arn)
  ```
- **No CloudWatch alarms.** The upstream CDK app adds alarms via
  `cdk-monitoring-constructs`; the Terraform parity hasn't been scoped
  yet. See the deferred items in `COA_sync_releases_TF.md` Appendix C.
- **No Makefile deploy target.** The `infra-tf/Makefile` leaves
  connectors to the operator — this module is called from your own
  Terraform configuration, not from `make up-all`.

## Parity to the upstream CDK app

Behaviour and resource shapes mirror
`connectors/databricks/cdk/lib/{connector,constants,single-target,managed-deployment}.ts`
at COA v0.3.5. If you need to port a feature upstream added later,
check the CDK code first — the Java jar is the shared behaviour, and
anything above it (env wiring, grants, SSM) is translated into this
module.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.14 |
| archive | ~> 2.4 |
| aws | ~> 6.0 |
| local | ~> 2.5 |

## Providers

| Name | Version |
|------|---------|
| archive | ~> 2.4 |
| aws | ~> 6.0 |
| local | ~> 2.5 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_policy.managed_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.secrets_env](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.spill](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.basic_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.managed_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.secrets_env](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.spill](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.vpc_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_alias.spill](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.spill](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key_policy.spill](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key_policy) | resource |
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_s3_bucket.spill](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.spill](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_policy.spill](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.spill_with_invokers](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.spill](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.spill](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.spill](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_security_group.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.function_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.role_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [local_file.staging](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| jar\_path | Local filesystem path to the Databricks connector fat jar (built from connectors/databricks via `mvn package`, published as `databricks-connector-<version>.jar`). The module uploads it to a temp zip at plan time; keep the file stable so Lambda doesn't redeploy on every apply. | `string` | n/a | yes |
| alarm\_topic\_arn | Optional SNS topic ARN. When set, every CloudWatch alarm this module creates publishes to it on breach. | `string` | `null` | no |
| config\_source | Which configuration shape the connector reads at request time:  - `environment` (default) — single Databricks endpoint, config from Lambda   env vars (DATABRICKS\_WORKSPACE\_HOST, DATABRICKS\_WAREHOUSE\_ID,   DATABRICKS\_CATALOG, DATABRICKS\_SCHEMA, CREDENTIAL\_SECRET\_ARN).   Customer-deployed in the customer's own AWS account against one   workspace+warehouse.  - `coa-managed` — one Lambda serves EVERY DATABRICKS\_SQL\_WAREHOUSE   source in one COA environment. Config per source is resolved from   SSM Parameter Store under `/<resource_prefix>/<env>/connectors/   databricks/sources/<sourceId>`. The sources API (`infra-tf/modules/   services/sources`) owns writing those parameters. | `string` | `"environment"` | no |
| credential\_kms\_key\_arn | Optional. Required when `credential_secret_arn` is encrypted with a customer-managed key — no existing grant covers it and every read fails `AccessDenied` without it. | `string` | `null` | no |
| credential\_secret\_arn | `environment` mode only. Secrets Manager ARN pointing to a secret with either `{token: ...}` (personal access token) or `{client_id: ..., client_secret: ...}` (OAuth m2m). A secret carrying both is refused. | `string` | `null` | no |
| databricks\_catalog | `environment` mode only. Unity Catalog name scoped by the credential. | `string` | `null` | no |
| databricks\_max\_rows\_per\_table | Row ceiling the connector applies to any single table read. Must match the Java default (DEFAULT\_MAX\_ROWS\_PER\_TABLE in `coa_sources_connectors_databricks`) if left null, which is 2,000,000. Set higher only when a legitimately large table is being truncated. The `ConnectorRowsReturned` CloudWatch alarm threshold tracks this value. | `number` | `null` | no |
| databricks\_schema | `environment` mode only. Default schema within the Unity Catalog. Required when the credential has access to more than one schema — scope exactly to what you intend to expose. | `string` | `null` | no |
| databricks\_warehouse\_id | `environment` mode only. Databricks SQL Warehouse id. | `string` | `null` | no |
| databricks\_workspace\_host | `environment` mode only. Databricks workspace host, e.g. `dbc-abcd-ef01.cloud.databricks.com`. | `string` | `null` | no |
| env | Deployment environment name (e.g. `dev`, `prd`). Combined with `resource_prefix` to build the function name. In the COA-managed mode, SSM parameter paths are also scoped by this value. | `string` | `"dev"` | no |
| log\_retention\_in\_days | CloudWatch Logs retention for `/aws/lambda/<function_name>`. Default 30 days matches the CDK. | `number` | `30` | no |
| memory\_size\_mb | Lambda memory in MB. Default 3008 matches upstream — the connector reads the whole predicate-matching row set to answer `GROUP BY` (Athena federation can't express aggregation). | `number` | `3008` | no |
| query\_role\_arns | IAM role ARNs allowed to invoke the connector Lambda and read its spill. In a COA-integrated deployment this is COA's serve runtime role plus the sources discovery role (reading /<prefix>/<env>/serve/runtime-role-arn and /<prefix>/<env>/sources/db-connector-role-arn from SSM). Leave empty for a connector-only test deploy. | `list(string)` | `[]` | no |
| resource\_prefix | Deployment resource prefix, e.g. `coa`. Function name is `<resource_prefix>-<env>-databricks-coa-connector` for customer deployments or `<resource_prefix>-<env>-managed-databricks-coa-connector` for COA-managed. The `-managed-` segment is reserved. | `string` | `"coa"` | no |
| retain\_spill\_on\_destroy | When true (prod convention), the spill bucket + CMK survive `terraform destroy` so an in-flight investigation of a hung query doesn't lose evidence. Default false — spill is scratch, every query older than itself is garbage. | `bool` | `false` | no |
| security\_group\_ids | Optional security groups for the Lambda. When null and VPC is set, the module creates one with HTTPS egress only (443/tcp to 0.0.0.0/0). | `list(string)` | `null` | no |
| subnet\_ids | Private subnets with egress route to the Databricks workspace (NAT or PrivateLink endpoint), Secrets Manager, KMS, and S3. See connectors/README.md. | `list(string)` | `[]` | no |
| tags | Additional tags to apply to every resource. The module always applies `coa:connector = true` on the Lambda and `coa:connector-spill = true` on the KMS key, since those tags are the invoke contract — do not override them. | `map(string)` | `{}` | no |
| timeout\_seconds | Lambda timeout in seconds. Default 600 covers a stopped SQL Warehouse resuming ahead of a large read. A runaway read is bounded by `databricks_max_rows_per_table` and the statement/socket timeouts inside the jar. | `number` | `600` | no |
| vpc\_id | Optional VPC id. When set, the Lambda runs with VPC attachments. Required for workspaces reachable only via PrivateLink. Both `vpc_id` and `subnet_ids` must be set together, or both left null. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| function\_arn | Connector Lambda ARN. Register as an Athena LAMBDA data catalog with `aws athena create-data-catalog --type LAMBDA --parameters function=<this>`. |
| function\_arn\_ssm\_parameter | SSM Parameter Store path where the function ARN is published. |
| function\_name | Connector Lambda function name. Carries the reserved `-managed-` segment in COA-managed mode. |
| log\_group\_name | CloudWatch Logs group backing the connector Lambda. |
| role\_arn | Connector execution role ARN. A customer's trust policy references this role when `datasource-access` roles trust the connector. |
| role\_arn\_ssm\_parameter | SSM Parameter Store path where the role ARN is published. |
| role\_name | Connector execution role name. |
| spill\_bucket\_arn | Spill bucket ARN. |
| spill\_bucket\_name | Spill bucket name. |
| spill\_kms\_key\_arn | Spill CMK ARN. Carries the `<resource_prefix>:connector-spill = true` tag that COA's query role's kms:Decrypt grant matches on. |
<!-- END_TF_DOCS -->
