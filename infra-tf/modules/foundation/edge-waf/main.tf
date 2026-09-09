# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Edge (CloudFront) WAF — MUST run in us-east-1. Ports the CDK EdgeWafStack,
# which instantiates the WafWebAcl construct with scope=CLOUDFRONT and
# namePrefix=cloudfront. This module is invoked at the root with
# providers = { aws = aws.us_east_1 }.
#
# CloudFront requires a CLOUDFRONT-scope WAFv2 WebACL, and such WebACLs can
# only be created in us-east-1. The WebACL ARN is published to SSM so the
# (possibly cross-region) web distribution can read it.

locals {
  # Mirrors the CDK construct: prefixed("cloudfront-waf") => <name_prefix>-cloudfront-waf.
  waf_name = "${var.name_prefix}-cloudfront-waf"

  # Rate-based rule is emitted only when the limit is > 0 (matches the CDK
  # `if (rateLimit > 0)` guard). Modeled as a for_each-driven dynamic block
  # rather than count so the rule is keyed, not indexed.
  rate_limit_rules = var.waf_rate_limit_per_5min > 0 ? { "RateLimitPerIp" = var.waf_rate_limit_per_5min } : {}
}

resource "aws_wafv2_web_acl" "this" {
  name  = local.waf_name
  scope = "CLOUDFRONT"

  # Allow by default; the managed rule group blocks matching malicious
  # requests. Standard "protective, not restrictive" posture.
  default_action {
    allow {}
  }

  # AWS-managed Common Rule Set. Managed rule groups define their own actions;
  # the WebACL must not override them (use `none`), only observe via metrics.
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 0

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.waf_name}-common-rule-set"
      sampled_requests_enabled   = true
    }
  }

  # Per-IP rate-based rule: block a source IP that exceeds the limit per
  # rolling 5-minute window. `block` because a rate breach is unambiguous
  # abuse. Disabled (omitted) when waf_rate_limit_per_5min is 0.
  dynamic "rule" {
    for_each = local.rate_limit_rules

    content {
      name     = rule.key
      priority = 1

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = rule.value
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "${local.waf_name}-rate-limit-per-ip"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = local.waf_name
    sampled_requests_enabled   = true
  }

  tags = {
    Component = var.component
  }
}

# Publish the CLOUDFRONT WebACL ARN so the (possibly cross-region) web
# distribution can consume it. Mirrors the CDK StringParameter write.
resource "aws_ssm_parameter" "cloudfront_web_acl_arn" {
  name  = "${var.ssm_prefix}/edge/cloudfront-web-acl-arn"
  type  = "String"
  value = aws_wafv2_web_acl.this.arn

  tags = {
    Component = var.component
  }
}
