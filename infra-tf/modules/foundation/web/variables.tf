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
