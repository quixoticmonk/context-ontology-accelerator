# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# REGIONAL WAF WebACL. Uses caller-provided ARN when set; otherwise
# auto-creates one with:
#   - Rule 0: block query strings > 4096 bytes, EXCEPT paginated
#             /tables paths (DataZone SearchAssets tokens are ~2.8KB
#             — the managed rule set's 2048-byte default blocks them).
#   - Rule 1: AWS Managed Common Rule Set with SizeRestrictions_QUERYSTRING
#             excluded (COUNT) so it doesn't fight the custom rule.
#   - Rule 2: Per-IP rate limit — waf_rate_limit_per_5min requests /
#             rolling 5-minute window.

resource "aws_wafv2_web_acl" "api" {
  count = var.api_web_acl_arn == null ? 1 : 0

  # Intentionally no `name` — let AWS generate a unique name so
  # replacement doesn't collide with the prior WebACL.
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # ── Rule 0: custom query-string size rule ─────────────────────────
  rule {
    name     = "SizeRestrictions-QueryString-ExceptPaginatedTables"
    priority = 0

    action {
      block {}
    }

    statement {
      and_statement {
        # Query string > 4096 bytes (generous for DataZone tokens).
        statement {
          size_constraint_statement {
            comparison_operator = "GT"
            size                = 4096

            field_to_match {
              query_string {}
            }

            text_transformation {
              priority = 0
              type     = "NONE"
            }
          }
        }

        # AND NOT a paginated tables path.
        statement {
          not_statement {
            statement {
              byte_match_statement {
                search_string         = "/tables"
                positional_constraint = "CONTAINS"

                field_to_match {
                  uri_path {}
                }

                text_transformation {
                  priority = 0
                  type     = "LOWERCASE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${local.waf_name}-size-qs-custom"
    }
  }

  # ── Rule 1: Common Rule Set (COUNT the SizeRestrictions QS rule) ──
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        vendor_name = "AWS"
        name        = "AWSManagedRulesCommonRuleSet"

        rule_action_override {
          name = "SizeRestrictions_QUERYSTRING"

          action_to_use {
            count {}
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${local.waf_name}-common-rule-set"
    }
  }

  # ── Rule 2: per-IP rate limit ─────────────────────────────────────
  rule {
    name     = "RateLimitPerIp"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit_per_5min
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "${local.waf_name}-rate-limit-per-ip"
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = local.waf_name
  }

  tags = local.tags
}

locals {
  effective_web_acl_arn = var.api_web_acl_arn != null ? var.api_web_acl_arn : aws_wafv2_web_acl.api[0].arn
}

resource "aws_wafv2_web_acl_association" "api" {
  resource_arn = aws_api_gateway_stage.this.arn
  web_acl_arn  = local.effective_web_acl_arn
}
