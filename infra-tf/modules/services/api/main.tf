# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# REST API Gateway + stage + deployment + logs + gateway responses
# + custom domain (optional) + Route53 alias (optional).

# ═════════════════════════════════════════════════════════════════════
#  REST API from the enriched OpenAPI spec
# ═════════════════════════════════════════════════════════════════════

resource "aws_api_gateway_rest_api" "this" {
  name        = local.api_name
  description = "Context Ontology Accelerator REST API"

  body = jsonencode(local.enriched_spec)

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  # Disable the raw execute-api endpoint when a custom domain is set —
  # requests then MUST come through the custom domain.
  disable_execute_api_endpoint = var.custom_domain != null

  # ── 501-stub guard (mirrors CDK ApiStack INTENTIONALLY_STUBBED check) ──
  # The spec→handler map falls back to the 501 stub for any unlisted path.
  # That is right for an operation with no backend yet, and wrong for a
  # finished feature whose handler simply isn't wired. Both symptoms are
  # silent — the stub returns 501 either way — so the only reliable
  # signal is a positive declaration: EVERY spec path must be either
  # wired in `var.path_handlers` or listed in `local.intentionally_stubbed`.
  # The reverse — a wired path still on the allowlist — is also an
  # error: the "did I forget to remove the allowlist entry?" symptom
  # vanishes once the backend lands, so catch it here.
  # Preconditions only fire when wiring is supplied (tests that construct
  # the module to assert on auth or WAF pass neither map, and all paths
  # correctly stub for them).
  lifecycle {
    precondition {
      condition     = !local.wiring_supplied || length(local.unexpectedly_stubbed) == 0
      error_message = "API paths would fall through to the 501 stub: ${join(", ", local.unexpectedly_stubbed)}. Add a path_handlers entry, or list the path in intentionally_stubbed (locals.tf) if it is deliberately unimplemented."
    }

    precondition {
      condition     = !local.wiring_supplied || length(local.wired_but_allowlisted) == 0
      error_message = "API paths are wired to a handler but still listed in intentionally_stubbed: ${join(", ", local.wired_but_allowlisted)}. Remove the allowlist entry now that the backend has landed."
    }
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  Deployment + stage
# ═════════════════════════════════════════════════════════════════════
# `aws_api_gateway_deployment.triggers` on the body hash ensures every
# spec change produces a new deployment.

# ═════════════════════════════════════════════════════════════════════
#  Account-level CloudWatch Logs role (singleton per account+region)
# ═════════════════════════════════════════════════════════════════════
# API Gateway refuses to enable stage access/execution logging until
# aws_api_gateway_account.cloudwatch_role_arn is set. It's an account-
# wide setting — only this module creates API Gateways so the singleton
# lives here. Uses the AWS-managed AmazonAPIGatewayPushToCloudWatchLogs
# policy for least-privilege.

data "aws_iam_policy_document" "apigw_logs_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "apigw_cloudwatch" {
  name               = "${var.name_prefix}-apigw-cloudwatch-logs"
  assume_role_policy = data.aws_iam_policy_document.apigw_logs_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "apigw_cloudwatch" {
  role       = aws_iam_role.apigw_cloudwatch.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch.arn

  # Depend on the attachment — API Gateway validates the role has the
  # right policy before accepting the setting.
  depends_on = [aws_iam_role_policy_attachment.apigw_cloudwatch]
}

resource "aws_cloudwatch_log_group" "access" {
  # checkov:skip=CKV_AWS_338:30-day retention is the current operational minimum for this non-regulated workload. Bump to >= 365 if compliance requirements change.
  name              = "${var.name_prefix}-api-access-logs"
  retention_in_days = 30
  kms_key_id        = var.logs_kms_key_arn

  tags = local.tags
}

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    body_hash = sha256(jsonencode(local.enriched_spec))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_lambda_permission.apigw_invoke,
    aws_lambda_permission.apigw_invoke_stub,
  ]
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = "prod"

  xray_tracing_enabled = true

  # Stage log config fails PutRestApi if the account-level logging role
  # isn't set yet — force apply order.
  depends_on = [aws_api_gateway_account.this]

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    # API Gateway rejects access-log configs that don't include either
    # $context.requestId or $context.extendedRequestId — it's the only
    # way to correlate an access-log line back to an execution log.
    #
    # principalId: this API uses a custom Lambda authorizer, so
    # $context.identity.caller/user are always "-"; the real caller is
    # $context.authorizer.principalId (the validated token's email, set by
    # the authorizer's _build_policy). Ported from api-stack.ts custom
    # access-log format (COA v0.3.7, V2298834436).
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      principalId    = "$context.authorizer.principalId"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
    })
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  Method settings — stage-wide + per-op expensive overrides
# ═════════════════════════════════════════════════════════════════════

resource "aws_api_gateway_method_settings" "stage_default" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    logging_level          = "INFO"
    data_trace_enabled     = false
    throttling_rate_limit  = var.throttle_rate_limit
    throttling_burst_limit = var.throttle_burst_limit
  }
}

resource "aws_api_gateway_method_settings" "expensive" {
  for_each = local.expensive_method_settings

  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = each.key

  settings {
    throttling_rate_limit  = each.value.throttling_rate_limit
    throttling_burst_limit = each.value.throttling_burst_limit
  }
}

# ═════════════════════════════════════════════════════════════════════
#  API Gateway invoke permission on every unique Lambda ARN
# ═════════════════════════════════════════════════════════════════════

# One invoke permission per unique Lambda. Keying by path (with 88+ paths)
# blew past Lambda's 20 KB resource-policy limit even though each statement
# is trivially redundant — API Gateway's source_arn wildcard (`/*/*`) covers
# every stage and method, so one permission per function is sufficient.
# Values from `var.path_handlers` are SSM-backed ARN strings resolved at
# plan time; the stub lives in this module and is granted separately so we
# don't reference an apply-time attribute inside a `for_each` key.
resource "aws_lambda_permission" "apigw_invoke" {
  # SSM data sources mark their values sensitive; that propagates to
  # `values(var.path_handlers)`. `for_each` refuses sensitive keys, so
  # peel the flag off — these are Lambda ARNs, not secrets.
  for_each = toset(nonsensitive(distinct(values(var.path_handlers))))

  statement_id_prefix = "AllowAPIGatewayInvoke"
  action              = "lambda:InvokeFunction"
  function_name       = each.value
  principal           = "apigateway.amazonaws.com"
  source_arn          = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_invoke_stub" {
  statement_id_prefix = "AllowAPIGatewayInvokeStub"
  action              = "lambda:InvokeFunction"
  function_name       = aws_lambda_function.stub.arn
  principal           = "apigateway.amazonaws.com"
  source_arn          = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

# ═════════════════════════════════════════════════════════════════════
#  Gateway responses — security headers on 4XX/5XX
# ═════════════════════════════════════════════════════════════════════

resource "aws_api_gateway_gateway_response" "default_4xx" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  response_type = "DEFAULT_4XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'${var.allowed_origin}'"
    "gatewayresponse.header.Strict-Transport-Security"   = "'max-age=63072000; includeSubDomains; preload'"
    "gatewayresponse.header.X-Content-Type-Options"      = "'nosniff'"
  }
}

resource "aws_api_gateway_gateway_response" "default_5xx" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  response_type = "DEFAULT_5XX"

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'${var.allowed_origin}'"
    "gatewayresponse.header.Strict-Transport-Security"   = "'max-age=63072000; includeSubDomains; preload'"
    "gatewayresponse.header.X-Content-Type-Options"      = "'nosniff'"
  }
}

# ═════════════════════════════════════════════════════════════════════
#  Custom domain (optional)
# ═════════════════════════════════════════════════════════════════════

resource "aws_api_gateway_domain_name" "this" {
  count = var.custom_domain != null ? 1 : 0

  domain_name              = var.custom_domain.api_domain_name
  regional_certificate_arn = var.custom_domain.api_certificate_arn
  security_policy          = "TLS_1_2"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = local.tags
}

resource "aws_api_gateway_base_path_mapping" "this" {
  count = var.custom_domain != null ? 1 : 0

  api_id      = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  domain_name = aws_api_gateway_domain_name.this[0].domain_name
}

resource "aws_route53_record" "api_alias" {
  count = var.custom_domain != null ? 1 : 0

  zone_id = var.custom_domain.hosted_zone_id
  name    = var.custom_domain.api_domain_name
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.this[0].regional_domain_name
    zone_id                = aws_api_gateway_domain_name.this[0].regional_zone_id
    evaluate_target_health = false
  }
}
