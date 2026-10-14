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
