# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "allowed_origin" {
  description = "CORS Access-Control-Allow-Origin value. Injected as the merged spec's <CorsOrigin> placeholder AND used verbatim by gateway responses + /health mock."
  type        = string
}

variable "api_web_acl_arn" {
  description = "REGIONAL WAFv2 WebACL ARN to associate with the API stage. When null, a WebACL with AWSManagedRulesCommonRuleSet (minus SizeRestrictions_QUERYSTRING for paginated DataZone tokens) + rate limit is auto-created by this module."
  type        = string
  default     = null
}

variable "cache_invalidation_table_arn" {
  description = "Cache invalidation DDB table ARN (from authnz module). Written to by the streams-fed cache_invalidation Lambda; read by the authorizer at request time."
  type        = string
}

variable "cache_invalidation_table_name" {
  description = "Cache invalidation DDB table name."
  type        = string
}

variable "component" {
  description = "Component tag applied to every resource in this module."
  type        = string
  default     = "api"
}

variable "control_plane_zip_path" {
  description = "Path to the shared control-plane Lambda zip (produced by modules/services/namespace/lambdas/control-plane/Makefile). Reused here for the authorizer + cache-invalidation handlers."
  type        = string
}

variable "custom_domain" {
  description = "REST API custom domain config. When null, uses the default execute-api endpoint. All fields required when set."
  type = object({
    api_domain_name     = string
    api_certificate_arn = string
    hosted_zone_id      = string
  })
  default = null
}

variable "expensive_throttle_burst_limit" {
  description = "Per-method burst limit for expensive job-launching operations. Applied to POST /induce, POST /rescan, POST /import-osi, and constraint-inference/validate/compile/accept routes."
  type        = number
  default     = 10
}

variable "expensive_throttle_rate_limit" {
  description = "Per-method steady-state rps for expensive job-launching operations."
  type        = number
  default     = 5
}

variable "expensive_api_operations" {
  description = "Expensive operation set — each entry gets `expensive_throttle_*` MethodSettings. Skipped for methods not present in the served spec so a stale entry doesn't create a phantom setting."
  type = list(object({
    method = string
    path   = string
  }))
  default = [
    { method = "POST", path = "/namespaces/{namespaceId}/induce" },
    { method = "POST", path = "/namespaces/{namespaceId}/sources/{sourceId}/rescan" },
    { method = "POST", path = "/namespaces/{namespaceId}/import-osi" },
    { method = "POST", path = "/namespaces/{namespaceId}/proposals/{proposalId}/infer-constraints" },
    { method = "POST", path = "/namespaces/{namespaceId}/proposals/{proposalId}/validate" },
    { method = "POST", path = "/namespaces/{namespaceId}/proposals/{proposalId}/compile-constraints" },
    { method = "POST", path = "/namespaces/{namespaceId}/proposals/{proposalId}/accept" },
  ]
}

variable "lambda_security_group_id" {
  description = "Lambda security group ID (from network) for authorizer + cache_invalidation Lambdas."
  type        = string
}
variable "logs_kms_key_arn" {
  description = "CMK ARN for CloudWatch Logs encryption (from modules/foundation/kms, published to <ssm_prefix>/kms/logs-key-arn). Applied to every aws_cloudwatch_log_group in this module."
  type        = string
}


variable "merged_spec_path" {
  description = "Path to the merged OpenAPI spec JSON (control-plane + data-layer, CorsOrigin substituted). Produced by modules/services/api/openapi/Makefile which runs merge.py on the two Smithy-generated specs."
  type        = string
}

variable "name_prefix" {
  description = "Physical resource name prefix (<resource_prefix>-<env>)."
  type        = string
}

variable "namespaces_table_arn" {
  description = "Namespaces DDB table ARN (from namespace module). Authorizer reads namespace status for the ARCHIVED mutation guard."
  type        = string
}

variable "path_handlers" {
  description = "Map of API path → Lambda invocation ARN. Every path in the merged spec that's NOT in this map falls through to a 501 stub Lambda. ARNs come from other module outputs at the root."
  type        = map(string)
  default     = {}
}

variable "private_subnet_ids" {
  description = "Private subnet IDs (from network) for the authorizer + cache_invalidation Lambda VPC config."
  type        = list(string)
}

variable "region" {
  description = "AWS region."
  type        = string
}

variable "resource_role_mappings_table_arn" {
  description = "Resource role mappings DDB table ARN (from authnz module). Streams source for cache_invalidation."
  type        = string
}

variable "resource_role_mappings_table_name" {
  description = "Resource role mappings DDB table name."
  type        = string
}

variable "resource_role_mappings_table_stream_arn" {
  description = "Resource role mappings DDB table stream ARN. Wired to the cache_invalidation Lambda via aws_lambda_event_source_mapping."
  type        = string
}

variable "roles_table_arn" {
  description = "Roles DDB table ARN (from authnz module). Streams source + authorizer read."
  type        = string
}

variable "roles_table_name" {
  description = "Roles DDB table name."
  type        = string
}

variable "roles_table_stream_arn" {
  description = "Roles DDB table stream ARN for cache_invalidation event source."
  type        = string
}

variable "ssm_prefix" {
  description = "SSM parameter root (e.g. /coa) for reading issuer/client_id/group_claim written by auth-idp."
  type        = string
}

variable "throttle_burst_limit" {
  description = "Stage-wide default burst limit (WAF-agnostic; front-door ceiling below AWS account default)."
  type        = number
  default     = 100
}

variable "throttle_rate_limit" {
  description = "Stage-wide default steady-state rps."
  type        = number
  default     = 50
}

variable "unsecured_paths" {
  description = "Paths that skip the custom authorizer (e.g. /health)."
  type        = list(string)
  default     = ["/health"]
}

variable "vpc_id" {
  description = "VPC ID (from network) for Lambda placement."
  type        = string
}

variable "waf_rate_limit_per_5min" {
  description = "Per-IP request limit over a rolling 5-minute window before the auto-created REGIONAL WebACL blocks the IP."
  type        = number
  default     = 2000
}
