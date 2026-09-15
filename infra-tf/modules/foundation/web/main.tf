# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Web hosting foundation: a private S3 website bucket served through a
# CloudFront distribution with Origin Access Control, security-headers
# response policy, and SPA error routing (403/404 -> index.html). Ports the
# CDK WebStack + PublicUIConstruct.
#
# The CDK's Cognito-callback and API-Gateway-CORS patches were AwsCustomResource
# (Lambda-backed) hacks; ownership of the callback patch moves to the auth-idp
# module, so is_cognito_mode drives no resource here (see variables.tf).

data "aws_caller_identity" "this" {}

data "aws_region" "this" {}

# IdP issuer + client ID published by the auth module. Read from SSM to avoid
# a hard cross-module dependency, matching the CDK valueForStringParameter.
data "aws_ssm_parameter" "issuer" {
  name = "${var.ssm_prefix}/issuer"
}

data "aws_ssm_parameter" "client_id" {
  name = "${var.ssm_prefix}/userpool-client-id"
}

# Auto-created CLOUDFRONT WebACL ARN published by the edge-waf module in
# us-east-1. Read through the us-east-1 aliased provider because CLOUDFRONT
# WebACLs (and the params describing them) live only in us-east-1.
data "aws_ssm_parameter" "auto_web_acl" {
  count    = var.web_acl_arn == null && var.auto_web_acl_param != null ? 1 : 0
  provider = aws.us_east_1

  name = var.auto_web_acl_param.name
}

# =====================================================================
#  Access-logs target bucket (CloudFront standard logging)
#
#  Legacy CloudFront standard logging delivers via a bucket ACL grant, so
#  this bucket enables ACLs (BUCKET_OWNER_PREFERRED / ObjectWriter) while
#  still blocking all public access. Logs expire after 90 days. Not
#  self-logging (would create a delivery loop).
# =====================================================================
resource "aws_s3_bucket" "access_logs" {
  bucket        = "${var.name_prefix}-cf-logs-${local.account_id}"
  force_destroy = true

  tags = { Component = var.component }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_ownership_controls" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =====================================================================
#  Website bucket — private, served only through CloudFront OAC
# =====================================================================
resource "aws_s3_bucket" "website" {
  bucket        = "${var.name_prefix}-ui-assets-${local.account_id}-${local.region}"
  force_destroy = true

  tags = { Component = var.component }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_s3_bucket_versioning" "website" {
  bucket = aws_s3_bucket.website.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "website" {
  bucket        = aws_s3_bucket.website.id
  target_bucket = aws_s3_bucket.access_logs.id
  target_prefix = "ui-assets/"
}

# Bucket policy: enforce TLS AND grant the CloudFront distribution read
# access via the OAC service principal (scoped to this distribution ARN).
data "aws_iam_policy_document" "website" {
  statement {
    sid       = "EnforceTLS"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.website.arn, "${aws_s3_bucket.website.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "AllowCloudFrontOAC"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.this.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website.json

  depends_on = [aws_s3_bucket_public_access_block.website]
}

# ── Website content sync ───────────────────────────────────────────
# One object per file under website_content_path; etag = filemd5 triggers a
# per-file redeploy on change. runtime-config.json is written separately so
# it always reflects the current backends.
resource "aws_s3_object" "website" {
  for_each = local.website_files

  bucket       = aws_s3_bucket.website.id
  key          = each.value
  source       = "${var.website_content_path}/${each.value}"
  etag         = filemd5("${var.website_content_path}/${each.value}")
  content_type = lookup(local.mime_types, element(reverse(split(".", each.value)), 0), "application/octet-stream")

  tags = { Component = var.component }
}

resource "aws_s3_object" "runtime_config" {
  bucket        = aws_s3_bucket.website.id
  key           = "runtime-config.json"
  content       = jsonencode(local.runtime_config)
  content_type  = "application/json"
  cache_control = "no-store, max-age=0"

  tags = { Component = var.component }
}

# =====================================================================
#  CloudFront distribution
# =====================================================================
resource "aws_cloudfront_origin_access_control" "this" {
  name                              = "${var.name_prefix}-ui-oac"
  description                       = "OAC for the ${var.name_prefix} website bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Security-headers response policy: HSTS (2y, preload), nosniff,
# frame-options DENY, strict-origin-when-cross-origin referrer, and the
# derived CSP. Cache-Control no-store mirrors the CDK custom header.
resource "aws_cloudfront_response_headers_policy" "security" {
  name = "${var.name_prefix}-security-headers"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }

    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    content_security_policy {
      content_security_policy = local.content_security_policy
      override                = true
    }
  }

  custom_headers_config {
    items {
      header   = "Cache-Control"
      value    = "no-store, max-age=0"
      override = false
    }
  }
}

resource "aws_cloudfront_distribution" "this" {
  comment             = "${var.name_prefix}-web-distribution"
  enabled             = true
  default_root_object = "index.html"
  aliases             = local.ui_domain_name != null ? [local.ui_domain_name] : []
  web_acl_id          = local.web_acl_arn

  origin {
    origin_id                = "s3-website"
    domain_name              = aws_s3_bucket.website.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  # Default behavior: static UI content, cache-optimized. Managed policy IDs:
  # CachingOptimized and CachingDisabled are AWS-managed and stable.
  default_cache_behavior {
    target_origin_id           = "s3-website"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = "658327ea-f89d-4fab-a63d-7e88639e58f6" # CachingOptimized
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # runtime-config.json must never be cached — it carries per-environment
  # API endpoints and auth settings that change between deploys.
  ordered_cache_behavior {
    path_pattern               = "runtime-config.json"
    target_origin_id           = "s3-website"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    cache_policy_id            = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # CachingDisabled
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # SPA routing: serve index.html for 403/404 so client-side routing works.
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  logging_config {
    bucket          = aws_s3_bucket.access_logs.bucket_domain_name
    prefix          = "cloudfront/"
    include_cookies = false
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Attaching an ACM cert (us-east-1) is what makes minimum_protocol_version
  # TLSv1.2_2021 take effect; the default CloudFront cert forces TLSv1.
  viewer_certificate {
    cloudfront_default_certificate = var.custom_domain == null
    acm_certificate_arn            = var.custom_domain != null ? var.custom_domain.ui_certificate_arn : null
    ssl_support_method             = var.custom_domain != null ? "sni-only" : null
    minimum_protocol_version       = var.custom_domain != null ? "TLSv1.2_2021" : "TLSv1"
  }

  tags = { Component = var.component }
}

# Route53 alias A record -> CloudFront, gated on a custom domain.
resource "aws_route53_record" "ui_alias" {
  count = var.custom_domain != null ? 1 : 0

  zone_id = var.custom_domain.hosted_zone_id
  name    = var.custom_domain.ui_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.this.domain_name
    zone_id                = aws_cloudfront_distribution.this.hosted_zone_id
    evaluate_target_health = false
  }
}

# ── SSM parameters ─────────────────────────────────────────────────
# Publish the distribution coordinates for runtime consumers, mirroring the
# CDK CfnOutput surface.
resource "aws_ssm_parameter" "distribution_id" {
  name        = "${var.ssm_prefix}/web/distribution-id"
  description = "CloudFront distribution ID for the web UI"
  type        = "String"
  value       = aws_cloudfront_distribution.this.id

  tags = { Component = var.component }
}

resource "aws_ssm_parameter" "distribution_domain_name" {
  name        = "${var.ssm_prefix}/web/distribution-domain-name"
  description = "CloudFront distribution domain name for the web UI"
  type        = "String"
  value       = aws_cloudfront_distribution.this.domain_name

  tags = { Component = var.component }
}
