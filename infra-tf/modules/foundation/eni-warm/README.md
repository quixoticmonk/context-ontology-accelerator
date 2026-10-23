# modules/foundation/eni-warm

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.14 |
| archive | >= 2.4 |
| aws | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| archive | >= 2.4 |
| aws | >= 6.0 |
| local | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.warm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.exec](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.warm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [local_file.handler](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| authorizer\_security\_group\_id | API authorizer SG. Pre-warms the dedicated authorizer combination so the authorizer Lambda does not pay the Hyperplane ENI create cost on its first deploy. | `string` | n/a | yes |
| discovery\_ocsp\_security\_group\_id | Snowflake OCSP SG. Combined with the shared Lambda SG, pre-warms the combination `sources-db-connector` uses for port-80 OCSP + port-443 HTTPS egress. | `string` | n/a | yes |
| ecs\_security\_group\_id | ECS task SG. Pre-warms the combination the vkg reload Lambda uses (runs on the ECS SG for Cloud Map DNS). | `string` | n/a | yes |
| lambda\_security\_group\_id | Shared Lambda SG. Pre-warms the combination used by every normal VPC Lambda (namespace API, metric API, control-plane, etc.). | `string` | n/a | yes |
| logs\_kms\_key\_arn | CMK ARN for CloudWatch Logs encryption, applied to each eni-warm function's log group. | `string` | n/a | yes |
| name\_prefix | Resource name prefix (e.g. `coa-dev`). Function names become `<name_prefix>-eni-warm-<combo>`. | `string` | n/a | yes |
| private\_subnet\_ids | Private-with-egress subnet IDs. Lambda creates one Hyperplane ENI per (subnet, SG-set) combination, so the ENI count is `len(subnets) * len(combos)`. | `list(string)` | n/a | yes |
| component | Component tag applied to every resource. Defaults to `foundation`. | `string` | `"foundation"` | no |
| tags | Tags applied to each eni-warm Lambda, log group, and the shared exec role. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| function\_arns | Map of combo key → warmer function ARN. |
| function\_names | Map of combo key → warmer function name. Service stacks don't invoke these; the names are published for operational visibility (CloudWatch log group lookup, cost allocation). |
| ready\_marker | Opaque marker that changes whenever the set of warmer functions changes. Published to SSM by the foundation stack; consumer stacks data-source it to form an implicit dependency on the warmers' creation. |
| role\_arn | Shared execution-role ARN for all warmer Lambdas. |
<!-- END_TF_DOCS -->
