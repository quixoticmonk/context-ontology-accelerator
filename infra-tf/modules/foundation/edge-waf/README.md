# modules/foundation/edge-waf

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
| [aws_ssm_parameter.cloudfront_web_acl_arn](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_wafv2_web_acl.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| name\_prefix | Physical resource name prefix (<resource\_prefix>-<env>). | `string` | n/a | yes |
| ssm\_prefix | SSM parameter root (e.g. /coa). The CloudFront WebACL ARN is published under this path for cross-region consumption by the web distribution. | `string` | n/a | yes |
| component | Component tag applied to every resource in this module. | `string` | `"foundation"` | no |
| waf\_rate\_limit\_per\_5min | Max requests per rolling 5-minute window from a single source IP before that IP is blocked (rate-based rule, IP aggregate). Set to 0 to disable the rate-limit rule. | `number` | `2000` | no |

## Outputs

| Name | Description |
|------|-------------|
| web\_acl\_arn | CLOUDFRONT-scope WAF WebACL ARN for the web distribution. |
| web\_acl\_id | CLOUDFRONT-scope WAF WebACL ID. |
| web\_acl\_ssm\_parameter\_name | SSM parameter name holding the CLOUDFRONT WebACL ARN (read cross-region by the web distribution). |
<!-- END_TF_DOCS -->
