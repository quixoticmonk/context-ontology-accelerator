# modules/foundation/web

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.14 |
| aws | >= 6.4, < 7.0 |

## Providers

| Name | Version |
|------|---------|
| aws | >= 6.4, < 7.0 |
| aws.us\_east\_1 | >= 6.4, < 7.0 |
| terraform | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_cloudfront_distribution.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution) | resource |
| [aws_cloudfront_origin_access_control.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_origin_access_control) | resource |
| [aws_cloudfront_response_headers_policy.security](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_response_headers_policy) | resource |
| [aws_iam_policy.api_cors_patch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.cognito_patch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.api_cors_patch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.cognito_patch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.api_cors_patch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.api_cors_patch_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.cognito_patch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.cognito_patch_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_function.api_cors_patch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.cognito_patch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_route53_record.ui_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_s3_bucket.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_logging.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_ownership_controls.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.access_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_versioning.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_object.runtime_config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_s3_object.website](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [aws_ssm_parameter.distribution_domain_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_ssm_parameter.distribution_id](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [terraform_data.api_cors_patch_trigger](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.cognito_callback_patch_trigger](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.invalidation_trigger](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| is\_cognito\_mode | Whether the auth stack provisioned a Cognito User Pool. In the CDK this gated a callback-URL patch on the user pool client; that patch is owned by the auth-idp module here, so this flag is retained for parity and drives no resource in this module. | `bool` | n/a | yes |
| name\_prefix | Physical resource name prefix (<resource\_prefix>-<env>). | `string` | n/a | yes |
| ssm\_prefix | SSM parameter root (e.g. /coa). CloudFront distribution coordinates are published under this path for runtime consumers. | `string` | n/a | yes |
| api\_cors\_patch\_zip\_path | Path to the built api-cors-patch Lambda zip. Required if `api_rest_api_id` is set. | `string` | `""` | no |
| api\_endpoint | Backend API Gateway invoke URL. Injected into runtime-config.json so the SPA discovers the API without a rebuild, and scoped into the connect-src CSP directive. | `string` | `null` | no |
| api\_rest\_api\_id | API Gateway REST API ID. Reserved for CloudFront API-path origin wiring; unused in the S3-only distribution the CDK ships. | `string` | `null` | no |
| api\_stage\_name | API Gateway stage name. Reserved for CloudFront API-path origin wiring; unused in the S3-only distribution the CDK ships. | `string` | `null` | no |
| auto\_web\_acl\_param | SSM parameter (name plus region) holding the auto-created CLOUDFRONT WebACL ARN published by the edge-waf module in us-east-1. Read via the aws.us\_east\_1 provider when web\_acl\_arn is not supplied. Null disables the auto lookup. | ```object({ name = string region = string })``` | `null` | no |
| cognito\_callback\_patch\_zip\_path | Path to the built cognito-callback-patch Lambda zip. Required when `user_pool_id` is set. | `string` | `""` | no |
| cognito\_extra\_callback\_urls | Additional callback URLs merged onto the Cognito web client alongside the CloudFront `/authenticate/` URL, e.g. `http://localhost:5173/authenticate/` so local `pnpm dev` and `coa-skills/control-plane/scripts/coa_login.py --client web` can sign in. Mirrors the CDK web-stack, which adds that URL on dev only. | `list(string)` | `[]` | no |
| cognito\_hosted\_ui\_origin | Full origin (scheme + host) of the Cognito hosted UI domain, e.g. `https://coa-dev-auth-697621333100.auth.us-east-1.amazoncognito.com`. Added to the CSP connect-src allowlist so the SPA can POST to /oauth2/token. Empty string when Cognito is not the IdP (OIDC mode). | `string` | `""` | no |
| component | Component tag applied to every resource in this module. | `string` | `"foundation"` | no |
| content\_security\_policy | Optional full-override Content-Security-Policy header value. When set (non-empty), the derived CSP is skipped entirely and this string is served as-is on the SPA's index response — matches the CDK's `content_security_policy` context knob, which existed so operators could extend the policy without patching source. Empty string keeps the derived policy in locals.tf. | `string` | `""` | no |
| custom\_domain | All-or-nothing custom domain config for the UI. ui\_certificate\_arn MUST be an ACM cert in us-east-1. When set, the distribution serves ui\_domain\_name and a Route53 alias A record is created in hosted\_zone\_id. Null serves the generated CloudFront domain with DNS managed externally. | ```object({ ui_domain_name = string ui_certificate_arn = string hosted_zone_id = string })``` | `null` | no |
| edge\_auth\_version\_arn | Versioned ARN of a Lambda@Edge viewer-request authorizer (e.g. the cloudfront-oidc-auth function) that gates the distribution. When set, it is associated with EVERY cache behavior as viewer-request so no path reaches the origin unauthenticated, plus a caching-disabled `/__auth/*` behavior for the authorizer's own login/callback/logout routes. MUST be a published version (never $LATEST) of a function in us-east-1. Null leaves the distribution ungated. | `string` | `null` | no |
| serve\_runtime\_arn | AgentCore Runtime ARN for SSE streaming queries. Injected into runtime-config.json and used to scope the bedrock-agentcore origin in the connect-src CSP directive. | `string` | `null` | no |
| user\_pool\_id | Cognito user pool ID (from auth-idp via SSM). When non-empty, the module patches the pool's client to register the CloudFront callback + logout URLs. Empty in OIDC mode. | `string` | `""` | no |
| userpool\_client\_id | Cognito user pool CLIENT ID (from auth-idp via SSM). Callback + logout allowlists are patched onto this client. | `string` | `""` | no |
| web\_acl\_arn | Caller-provided CLOUDFRONT-scope WAF WebACL ARN to associate with the distribution. Takes precedence over auto\_web\_acl\_param. Null falls back to the auto lookup, then to no WAF. | `string` | `null` | no |
| website\_content\_path | Local path to the built Vite dist directory. When set, every file under it is synced to the website bucket as an aws\_s3\_object. Null provisions the distribution without uploading content (content deployed out of band). | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| distribution\_arn | CloudFront distribution ARN (for WAF association and IAM policies). |
| distribution\_domain\_name | CloudFront distribution domain name (e.g. dxxxx.cloudfront.net). |
| distribution\_id | CloudFront distribution ID. |
| website\_bucket\_arn | ARN of the private website content bucket. |
| website\_bucket\_name | Name of the private website content bucket. |
<!-- END_TF_DOCS -->
