# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

variable "api_endpoint" {
  description = "Backend API Gateway invoke URL. Injected into runtime-config.json so the SPA discovers the API without a rebuild, and scoped into the connect-src CSP directive."
  type        = string
  default     = null
}

variable "api_rest_api_id" {
  description = "API Gateway REST API ID. Reserved for CloudFront API-path origin wiring; unused in the S3-only distribution the CDK ships."
  type        = string
  default     = null
}

variable "api_stage_name" {
  description = "API Gateway stage name. Reserved for CloudFront API-path origin wiring; unused in the S3-only distribution the CDK ships."
  type        = string
  default     = null
}

variable "auto_web_acl_param" {
  description = "SSM parameter (name plus region) holding the auto-created CLOUDFRONT WebACL ARN published by the edge-waf module in us-east-1. Read via the aws.us_east_1 provider when web_acl_arn is not supplied. Null disables the auto lookup."
  type = object({
    name   = string
    region = string
  })
  default = null
}

variable "component" {
  description = "Component tag applied to every resource in this module."
  type        = string
  default     = "foundation"
}

variable "custom_domain" {
  description = "All-or-nothing custom domain config for the UI. ui_certificate_arn MUST be an ACM cert in us-east-1. When set, the distribution serves ui_domain_name and a Route53 alias A record is created in hosted_zone_id. Null serves the generated CloudFront domain with DNS managed externally."
  type = object({
    ui_domain_name     = string
    ui_certificate_arn = string
    hosted_zone_id     = string
  })
  default = null
}

variable "edge_auth_version_arn" {
  description = "Versioned ARN of a Lambda@Edge viewer-request authorizer (e.g. the cloudfront-oidc-auth function) that gates the distribution. When set, it is associated with EVERY cache behavior as viewer-request so no path reaches the origin unauthenticated, plus a caching-disabled `/__auth/*` behavior for the authorizer's own login/callback/logout routes. MUST be a published version (never $LATEST) of a function in us-east-1. Null leaves the distribution ungated."
  type        = string
  default     = null

  validation {
    condition     = var.edge_auth_version_arn == null || can(regex("^arn:aws[a-z-]*:lambda:us-east-1:[0-9]{12}:function:[A-Za-z0-9_-]+:[0-9]+$", var.edge_auth_version_arn))
    error_message = "edge_auth_version_arn must be a versioned Lambda ARN in us-east-1 (arn:aws:lambda:us-east-1:<account>:function:<name>:<version>)."
  }
}

variable "is_cognito_mode" {
  description = "Whether the auth stack provisioned a Cognito User Pool. In the CDK this gated a callback-URL patch on the user pool client; that patch is owned by the auth-idp module here, so this flag is retained for parity and drives no resource in this module."
  type        = bool
}

variable "name_prefix" {
  description = "Physical resource name prefix (<resource_prefix>-<env>)."
  type        = string
}

variable "serve_runtime_arn" {
  description = "AgentCore Runtime ARN for SSE streaming queries. Injected into runtime-config.json and used to scope the bedrock-agentcore origin in the connect-src CSP directive."
  type        = string
  default     = null
}

variable "mcp_runtime_arn" {
  description = "MCP server AgentCore Runtime ARN (from the mcp module). Injected into runtime-config.json so the console's MCP page can surface the endpoint and a copy-paste client config for this deployment."
  type        = string
  default     = null
}

variable "ssm_prefix" {
  description = "SSM parameter root (e.g. /coa). CloudFront distribution coordinates are published under this path for runtime consumers."
  type        = string
}

variable "web_acl_arn" {
  description = "Caller-provided CLOUDFRONT-scope WAF WebACL ARN to associate with the distribution. Takes precedence over auto_web_acl_param. Null falls back to the auto lookup, then to no WAF."
  type        = string
  default     = null
}

variable "website_content_path" {
  description = "Local path to the built Vite dist directory. When set, every file under it is synced to the website bucket as an aws_s3_object. Null provisions the distribution without uploading content (content deployed out of band)."
  type        = string
  default     = null
}

variable "user_pool_id" {
  description = "Cognito user pool ID (from auth-idp via SSM). When non-empty, the module patches the pool's client to register the CloudFront callback + logout URLs. Empty in OIDC mode."
  type        = string
  default     = ""
}

variable "userpool_client_id" {
  description = "Cognito user pool CLIENT ID (from auth-idp via SSM). Callback + logout allowlists are patched onto this client."
  type        = string
  default     = ""
}

variable "cognito_callback_patch_zip_path" {
  description = "Path to the built cognito-callback-patch Lambda zip. Required when `user_pool_id` is set."
  type        = string
  default     = ""
}

variable "cognito_extra_callback_urls" {
  description = "Additional callback URLs merged onto the Cognito web client alongside the CloudFront `/authenticate/` URL, e.g. `http://localhost:5173/authenticate/` so local `pnpm dev` and `coa-skills/control-plane/scripts/coa_login.py --client web` can sign in. Mirrors the CDK web-stack, which adds that URL on dev only."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for u in var.cognito_extra_callback_urls : can(regex("^(https://|http://localhost(:[0-9]+)?/)", u))])
    error_message = "Each extra callback URL must be https:// or an http://localhost[:port]/ loopback URL."
  }
}

variable "cognito_hosted_ui_origin" {
  description = "Full origin (scheme + host) of the Cognito hosted UI domain, e.g. `https://coa-dev-auth-697621333100.auth.us-east-1.amazoncognito.com`. Added to the CSP connect-src allowlist so the SPA can POST to /oauth2/token. Empty string when Cognito is not the IdP (OIDC mode)."
  type        = string
  default     = ""
}

variable "content_security_policy" {
  description = "Optional full-override Content-Security-Policy header value. When set (non-empty), the derived CSP is skipped entirely and this string is served as-is on the SPA's index response — matches the CDK's `content_security_policy` context knob, which existed so operators could extend the policy without patching source. Empty string keeps the derived policy in locals.tf."
  type        = string
  default     = ""
}

variable "api_cors_patch_zip_path" {
  description = "Path to the built api-cors-patch Lambda zip. Required if `api_rest_api_id` is set."
  type        = string
  default     = ""
}
