# modules/foundation/guardrail

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
| [aws_bedrock_guardrail.retrieval](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrock_guardrail) | resource |
| [aws_bedrock_guardrail.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrock_guardrail) | resource |
| [aws_bedrock_guardrail_version.retrieval](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrock_guardrail_version) | resource |
| [aws_bedrock_guardrail_version.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrock_guardrail_version) | resource |
| [aws_ssm_parameter.guardrail_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.guardrail_version](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.retrieval_guardrail_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.retrieval_guardrail_version](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name\_prefix | Physical resource name prefix (<resource\_prefix>-<env>). | `string` | n/a | yes |
| ssm\_prefix | SSM parameter root (e.g. /coa). Runtime services read guardrail IDs/versions under this path. | `string` | n/a | yes |
| component | Component tag applied to every resource in this module. | `string` | `"foundation"` | no |

## Outputs

| Name | Description |
|------|-------------|
| guardrail\_arn | Primary guardrail ARN (LLM input/output boundary; content filters + PII anonymization). |
| guardrail\_id | Primary guardrail ID. |
| guardrail\_version | Primary guardrail published version. |
| retrieval\_guardrail\_arn | Retrieval guardrail ARN (ingested/retrieved content screening; content filters only, no PII policy). |
| retrieval\_guardrail\_id | Retrieval guardrail ID. |
| retrieval\_guardrail\_version | Retrieval guardrail published version. |
<!-- END_TF_DOCS -->
