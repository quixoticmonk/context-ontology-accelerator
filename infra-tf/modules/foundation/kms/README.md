# modules/foundation/kms

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.7 |
| aws | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| aws | ~> 6.0 |

## Resources

| Name | Type |
|------|------|
| [aws_kms_alias.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_ssm_parameter.logs_key_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name\_prefix | Physical resource name prefix (<resource\_prefix>-<env>). | `string` | n/a | yes |
| region | AWS region. Used to scope the CloudWatch Logs service-principal grant in the key policy to logs.<region>.amazonaws.com. | `string` | n/a | yes |
| ssm\_prefix | SSM parameter root (e.g. /coa). The log-encryption key ARN is written under <ssm\_prefix>/kms/logs-key-arn for downstream stacks to consume. | `string` | n/a | yes |
| component | Component tag applied to every resource in this module. | `string` | `"kms"` | no |

## Outputs

| Name | Description |
|------|-------------|
| logs\_key\_alias | Alias of the CloudWatch Logs encryption CMK. |
| logs\_key\_arn | ARN of the CloudWatch Logs encryption CMK. Consumers should prefer reading this from SSM (see modules/foundation/kms/main.tf) so this module can be moved without rewiring. |
<!-- END_TF_DOCS -->
