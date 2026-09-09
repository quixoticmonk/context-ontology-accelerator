# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  account_id = data.aws_caller_identity.this.account_id
  region     = data.aws_region.this.region

  # runtime-config.json is served from S3 and read by the SPA at load time
  # so backends can change without a rebuild. Optional keys are omitted (not
  # emitted as null) to mirror the CDK buildRuntimeConfig include/omit logic.
  ui_domain_name = var.custom_domain != null ? var.custom_domain.ui_domain_name : null
  site_url       = local.ui_domain_name != null ? "https://${local.ui_domain_name}" : "https://${aws_cloudfront_distribution.this.domain_name}"

  runtime_config = merge(
    {
      region    = local.region
      authority = data.aws_ssm_parameter.issuer.value
      clientId  = data.aws_ssm_parameter.client_id.value
    },
    var.api_endpoint != null ? { apiEndpoint = var.api_endpoint } : {},
    var.serve_runtime_arn != null ? { serveRuntimeArn = var.serve_runtime_arn } : {},
  )

  # ── CloudFront WebACL ARN resolution ───────────────────────────────
  # Caller-provided ARN wins; otherwise read the ARN the edge-waf module
  # published to SSM in us-east-1; otherwise deploy without a WebACL.
  resolved_web_acl_arn = coalesce(
    var.web_acl_arn,
    var.auto_web_acl_param != null ? data.aws_ssm_parameter.auto_web_acl[0].value : null,
    "",
  )
  web_acl_arn = local.resolved_web_acl_arn != "" ? local.resolved_web_acl_arn : null

  # ── Content-Security-Policy ────────────────────────────────────────
  # Ported from buildContentSecurityPolicy: script-src 'self' is the primary
  # XSS control; connect-src/frame-src are scoped to the app's real origins
  # when known at apply time. The API origin falls back to scheme-level
  # (https:) before the endpoint is wired so the app still functions.
  api_origin  = var.api_endpoint != null ? regex("^https?://[^/]+", var.api_endpoint) : null
  auth_origin = trimspace(data.aws_ssm_parameter.issuer.value) != "" ? regex("^https?://[^/]+", data.aws_ssm_parameter.issuer.value) : null

  agentcore_origin = var.serve_runtime_arn != null ? "https://bedrock-agentcore.${local.region}.amazonaws.com" : null
  cognito_origin   = "https://cognito-idp.${local.region}.amazonaws.com"

  connect_src = distinct(concat(
    ["'self'"],
    compact([local.api_origin, local.auth_origin, local.agentcore_origin, local.cognito_origin]),
    local.api_origin == null ? ["https:"] : [],
  ))

  frame_src = distinct(concat(
    ["'self'"],
    compact([local.auth_origin, local.cognito_origin]),
  ))

  content_security_policy = join("; ", [
    "default-src 'self'",
    "script-src 'self'",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data:",
    "font-src 'self' data:",
    "connect-src ${join(" ", local.connect_src)}",
    "frame-src ${join(" ", local.frame_src)}",
    "object-src 'none'",
    "base-uri 'self'",
    "frame-ancestors 'none'",
    "form-action 'self'",
  ])

  # ── Website content sync ───────────────────────────────────────────
  # Every file under website_content_path is uploaded as its own object.
  # runtime-config.json is written separately (jsonencode) so it always
  # reflects the current backends even without a content rebuild.
  website_files = var.website_content_path != null ? fileset(var.website_content_path, "**") : toset([])

  # Minimal MIME table for the Vite dist output; unknown extensions fall
  # back to application/octet-stream via the lookup default.
  mime_types = {
    css   = "text/css"
    html  = "text/html"
    ico   = "image/x-icon"
    js    = "application/javascript"
    json  = "application/json"
    map   = "application/json"
    png   = "image/png"
    svg   = "image/svg+xml"
    txt   = "text/plain"
    webp  = "image/webp"
    woff  = "font/woff"
    woff2 = "font/woff2"
  }
}
