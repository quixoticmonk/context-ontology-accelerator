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

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  Deployment + stage
# ═════════════════════════════════════════════════════════════════════
# `aws_api_gateway_deployment.triggers` on the body hash ensures every
# spec change produces a new deployment.

resource "aws_cloudwatch_log_group" "access" {
  name              = "${var.name_prefix}-api-access-logs"
  retention_in_days = 30

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
  ]
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = "prod"

  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      caller         = "$context.identity.caller"
      httpMethod     = "$context.httpMethod"
      ip             = "$context.identity.sourceIp"
      protocol       = "$context.protocol"
      requestTime    = "$context.requestTime"
      resourcePath   = "$context.resourcePath"
      responseLength = "$context.responseLength"
      status         = "$context.status"
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

resource "aws_lambda_permission" "apigw_invoke" {
  for_each = toset(local.unique_lambda_arns)

  statement_id_prefix = "AllowAPIGatewayInvoke"
  action              = "lambda:InvokeFunction"
  function_name       = each.value
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
