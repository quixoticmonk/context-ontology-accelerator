# modules/services/api

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.13 |
| archive | ~> 2.7 |
| aws | ~> 6.0 |

## Providers

| Name | Version |
|------|---------|
| archive | ~> 2.7 |
| aws | ~> 6.0 |

## Resources

| Name | Type |
|------|------|
| [aws_api_gateway_account.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_account) | resource |
| [aws_api_gateway_base_path_mapping.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_base_path_mapping) | resource |
| [aws_api_gateway_deployment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_deployment) | resource |
| [aws_api_gateway_domain_name.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_domain_name) | resource |
| [aws_api_gateway_gateway_response.default_4xx](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_gateway_response) | resource |
| [aws_api_gateway_gateway_response.default_5xx](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_gateway_response) | resource |
| [aws_api_gateway_method_settings.expensive](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_settings) | resource |
| [aws_api_gateway_method_settings.stage_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_method_settings) | resource |
| [aws_api_gateway_rest_api.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api) | resource |
| [aws_api_gateway_stage.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_stage) | resource |
| [aws_cloudwatch_log_group.access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.cache_invalidation_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_iam_policy.authorizer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.cache_invalidation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.apigw_cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.authorizer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.authorizer_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.cache_invalidation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.stub](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.authorizer_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.apigw_cloudwatch](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.authorizer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.authorizer_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.cache_invalidation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.cache_invalidation_vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.stub_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_event_source_mapping.roles_stream](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_event_source_mapping.rrm_stream](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_event_source_mapping) | resource |
| [aws_lambda_function.authorizer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.cache_invalidation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.stub](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.apigw_invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.apigw_invoke_stub](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_route53_record.api_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_sqs_queue.cache_invalidation_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_policy.cache_invalidation_dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_wafv2_web_acl.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl) | resource |
| [aws_wafv2_web_acl_association.api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/wafv2_web_acl_association) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| allowed\_origin | CORS Access-Control-Allow-Origin value. Injected as the merged spec's <CorsOrigin> placeholder AND used verbatim by gateway responses + /health mock. | `string` | n/a | yes |
| authorizer\_security\_group\_id | API authorizer Lambda security group ID (from network). Dedicated SG with unrestricted outbound so an external OIDC IdP's JWKS endpoint can be reached on any port. | `string` | n/a | yes |
| cache\_invalidation\_table\_arn | Cache invalidation DDB table ARN (from authnz module). Written to by the streams-fed cache\_invalidation Lambda; read by the authorizer at request time. | `string` | n/a | yes |
| cache\_invalidation\_table\_name | Cache invalidation DDB table name. | `string` | n/a | yes |
| control\_plane\_zip\_path | Path to the shared control-plane Lambda zip (produced by modules/services/namespace/lambdas/control-plane/Makefile). Reused here for the authorizer + cache-invalidation handlers. | `string` | n/a | yes |
| lambda\_security\_group\_id | Lambda security group ID (from network) for the cache-invalidation Lambda (HTTPS/DDB egress). The API authorizer uses the separate `authorizer_security_group_id` instead. | `string` | n/a | yes |
| logs\_kms\_key\_arn | CMK ARN for CloudWatch Logs encryption (from modules/foundation/kms, published to <ssm\_prefix>/kms/logs-key-arn). Applied to every aws\_cloudwatch\_log\_group in this module. | `string` | n/a | yes |
| merged\_spec\_path | Path to the merged OpenAPI spec JSON (control-plane + data-layer, CorsOrigin substituted). Produced by modules/services/api/openapi/Makefile which runs merge.py on the two Smithy-generated specs. | `string` | n/a | yes |
| name\_prefix | Physical resource name prefix (<resource\_prefix>-<env>). | `string` | n/a | yes |
| namespaces\_table\_arn | Namespaces DDB table ARN (from namespace module). Authorizer reads namespace status for the ARCHIVED mutation guard. | `string` | n/a | yes |
| private\_subnet\_ids | Private subnet IDs (from network) for the authorizer + cache\_invalidation Lambda VPC config. | `list(string)` | n/a | yes |
| region | AWS region. | `string` | n/a | yes |
| resource\_role\_mappings\_table\_arn | Resource role mappings DDB table ARN (from authnz module). Streams source for cache\_invalidation. | `string` | n/a | yes |
| resource\_role\_mappings\_table\_name | Resource role mappings DDB table name. | `string` | n/a | yes |
| resource\_role\_mappings\_table\_stream\_arn | Resource role mappings DDB table stream ARN. Wired to the cache\_invalidation Lambda via aws\_lambda\_event\_source\_mapping. | `string` | n/a | yes |
| roles\_table\_arn | Roles DDB table ARN (from authnz module). Streams source + authorizer read. | `string` | n/a | yes |
| roles\_table\_name | Roles DDB table name. | `string` | n/a | yes |
| roles\_table\_stream\_arn | Roles DDB table stream ARN for cache\_invalidation event source. | `string` | n/a | yes |
| ssm\_prefix | SSM parameter root (e.g. /coa) for reading issuer/client\_id/group\_claim written by auth-idp. | `string` | n/a | yes |
| vpc\_id | VPC ID (from network) for Lambda placement. | `string` | n/a | yes |
| api\_web\_acl\_arn | REGIONAL WAFv2 WebACL ARN to associate with the API stage. When null, a WebACL with AWSManagedRulesCommonRuleSet (minus SizeRestrictions\_QUERYSTRING for paginated DataZone tokens) + rate limit is auto-created by this module. | `string` | `null` | no |
| component | Component tag applied to every resource in this module. | `string` | `"api"` | no |
| custom\_domain | REST API custom domain config. When null, uses the default execute-api endpoint. All fields required when set. | ```object({ api_domain_name = string api_certificate_arn = string hosted_zone_id = string })``` | `null` | no |
| expensive\_api\_operations | Expensive operation set — each entry gets `expensive_throttle_*` MethodSettings. Skipped for methods not present in the served spec so a stale entry doesn't create a phantom setting. | ```list(object({ method = string path = string }))``` | ```[ { "method": "POST", "path": "/namespaces/{namespaceId}/induce" }, { "method": "POST", "path": "/namespaces/{namespaceId}/sources/{sourceId}/rescan" }, { "method": "POST", "path": "/namespaces/{namespaceId}/import-osi" }, { "method": "POST", "path": "/namespaces/{namespaceId}/proposals/{proposalId}/infer-constraints" }, { "method": "POST", "path": "/namespaces/{namespaceId}/proposals/{proposalId}/validate" }, { "method": "POST", "path": "/namespaces/{namespaceId}/proposals/{proposalId}/compile-constraints" }, { "method": "POST", "path": "/namespaces/{namespaceId}/proposals/{proposalId}/accept" } ]``` | no |
| expensive\_throttle\_burst\_limit | Per-method burst limit for expensive job-launching operations. Applied to POST /induce, POST /rescan, POST /import-osi, and constraint-inference/validate/compile/accept routes. | `number` | `10` | no |
| expensive\_throttle\_rate\_limit | Per-method steady-state rps for expensive job-launching operations. | `number` | `5` | no |
| path\_handlers | Map of API path → Lambda invocation ARN. Every path in the merged spec that's NOT in this map falls through to a 501 stub Lambda. ARNs come from other module outputs at the root. | `map(string)` | `{}` | no |
| throttle\_burst\_limit | Stage-wide default burst limit (WAF-agnostic; front-door ceiling below AWS account default). | `number` | `100` | no |
| throttle\_rate\_limit | Stage-wide default steady-state rps. | `number` | `50` | no |
| unsecured\_paths | Paths that skip the custom authorizer (e.g. /health). | `list(string)` | ```[ "/health" ]``` | no |
| waf\_rate\_limit\_per\_5min | Per-IP request limit over a rolling 5-minute window before the auto-created REGIONAL WebACL blocks the IP. | `number` | `2000` | no |

## Outputs

| Name | Description |
|------|-------------|
| api\_endpoint | REST API base URL. When a custom domain is configured this is the custom domain URL; otherwise the default execute-api URL. |
| api\_id | REST API ID. |
| authorizer\_fn\_arn | Custom authorizer Lambda ARN. |
| cache\_invalidation\_dlq\_arn | DLQ ARN for cache-invalidation events that failed all retries. Alarm rings on any message here. |
| cache\_invalidation\_fn\_arn | Cache-invalidation Lambda ARN. |
| stage\_arn | API Gateway stage ARN. |
| stage\_name | API Gateway stage name. |
| web\_acl\_arn | Effective REGIONAL WAF WebACL ARN attached to the stage (caller-provided or auto-created). |
<!-- END_TF_DOCS -->
