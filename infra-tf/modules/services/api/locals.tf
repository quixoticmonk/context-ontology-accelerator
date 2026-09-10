# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  tags = { Component = var.component }

  api_name         = "${var.name_prefix}-api"
  authorizer_name  = "${var.name_prefix}-authorizer"
  cache_inval_name = "${var.name_prefix}-cache-invalidation"
  stub_name        = "${var.name_prefix}-api-not-implemented"
  waf_name         = "${var.name_prefix}-api-waf"

  # ── OpenAPI enrichment (HCL) ────────────────────────────────────────
  # Load the merged base spec (control-plane + data-layer, CorsOrigin
  # already substituted by the Makefile). Then inject per-path Lambda
  # proxy integrations, patch /health to a mock, and fill authorizer
  # parameters.
  merged_spec_raw = jsondecode(file(var.merged_spec_path))

  http_methods = ["get", "put", "post", "delete", "patch", "head"]

  # For each path in the spec, resolve the target Lambda ARN. Falls
  # back to the stub Lambda when the path isn't in var.path_handlers —
  # matching CDK's `handlers[apiPath] ?? stubFn.functionArn`.
  path_arns = {
    for path, _methods in local.merged_spec_raw.paths :
    path => lookup(var.path_handlers, path, aws_lambda_function.stub.arn)
  }

  # Response headers to overlay on every operation's responses.
  # `Access-Control-Allow-Origin` must be declared here because the
  # /health mock integration sets it via responseParameters, and API
  # Gateway rejects PutRestApi when integration-level headers don't
  # exist as method-response headers.
  security_response_headers = {
    "Access-Control-Allow-Origin" = { schema = { type = "string" } }
    "Strict-Transport-Security"   = { schema = { type = "string" } }
    "X-Content-Type-Options"      = { schema = { type = "string" } }
    "X-Frame-Options"             = { schema = { type = "string" } }
    "Cache-Control"               = { schema = { type = "string" } }
    "Referrer-Policy"             = { schema = { type = "string" } }
  }

  authorizer_invoke_uri = "arn:${data.aws_partition.current.partition}:apigateway:${var.region}:lambda:path/2015-03-31/functions/${aws_lambda_function.authorizer.arn}/invocations"

  # /health MOCK integration — served by API Gateway itself, no Lambda.
  # Static response headers because there's no Lambda to populate them;
  # `Cache-Control: no-store` is the functional one — an intermediary
  # caching "ok" would keep reporting a healthy API after it stopped
  # being one.
  health_mock_integration = {
    type                = "mock"
    passthroughBehavior = "when_no_match"
    requestTemplates    = { "application/json" = "{\"statusCode\": 200}" }
    responses = {
      default = {
        statusCode = "200"
        responseParameters = {
          "method.response.header.Access-Control-Allow-Origin" = "'${var.allowed_origin}'"
          "method.response.header.Cache-Control"               = "'no-store'"
          "method.response.header.Strict-Transport-Security"   = "'max-age=63072000; includeSubDomains; preload'"
          "method.response.header.X-Content-Type-Options"      = "'nosniff'"
        }
        responseTemplates = { "application/json" = "{\"status\":\"ok\"}" }
      }
    }
  }


  # Build the enriched spec:
  #  1. Start from local.merged_spec_raw
  #  2. For every (path, method) that is a real HTTP method operation,
  #     overlay: security_response_headers on each response + inject
  #     x-amazon-apigateway-integration
  #  3. Patch /health.get integration to the mock
  #  4. Rewrite securitySchemes for API Gateway custom authorizer
  #  5. Attach per-op security = [ { <scheme> = [] } ] on secured paths;
  #     security = [] on unsecured paths
  enriched_spec = merge(local.merged_spec_raw, {
    paths = {
      for path, methods in local.merged_spec_raw.paths :
      path => merge(
        methods,
        {
          for method, op in methods : method => merge(op, {
            # Overlay security response headers on every response.
            responses = {
              for code, response in op.responses : code => merge(response, {
                headers = merge(try(response.headers, {}), local.security_response_headers)
              })
            }
            # AWS_PROXY integration to the resolved Lambda ARN, or /health
            # mock for the health probe. Terraform's ternary requires both
            # branches to have the same object type, so pad missing keys with
            # null — jsonencode() strips nulls at serialization, so the API
            # Gateway spec is identical to hand-authored either variant.
            "x-amazon-apigateway-integration" = (path == "/health" && method == "get") ? {
              type                = "mock"
              passthroughBehavior = local.health_mock_integration.passthroughBehavior
              requestTemplates    = local.health_mock_integration.requestTemplates
              responses           = local.health_mock_integration.responses
              httpMethod          = null
              uri                 = null
              } : {
              type                = "aws_proxy"
              passthroughBehavior = "when_no_match"
              requestTemplates    = null
              responses           = null
              httpMethod          = "POST"
              uri                 = "arn:${data.aws_partition.current.partition}:apigateway:${var.region}:lambda:path/2015-03-31/functions/${local.path_arns[path]}/invocations"
            }
            # Per-op security: authorizer for secured paths, empty for unsecured.
            security = contains(var.unsecured_paths, path) ? [] : [
              for scheme_name, _ in try(local.merged_spec_raw.components.securitySchemes, {}) : { (scheme_name) = [] }
            ]
          }) if contains(local.http_methods, method)
        },
        # Preserve non-method top-level path keys (parameters, options, etc.).
        # Smithy emits `options` with a canned CORS-preflight mock integration
        # (security = [], responseHeaders set). Preserving it as-is is what
        # gives us browser-side CORS preflight support end-to-end.
        { for k, v in methods : k => v if !contains(local.http_methods, k) },
      )
    }
    components = merge(try(local.merged_spec_raw.components, {}), {
      # Rewrite every security scheme carrying an
      # x-amazon-apigateway-authorizer into an apiKey/Authorization
      # header scheme, and populate authorizerUri +
      # authorizerCredentials with the runtime values. Smithy emits
      # http/Bearer which API Gateway rejects.
      #
      # Split into two for-loops (one per branch) so each loop's values
      # have a uniform shape — Terraform's strict-type ternary rejects
      # branches with different object attribute sets in a single map.
      securitySchemes = merge(
        {
          for name, scheme in try(local.merged_spec_raw.components.securitySchemes, {}) :
          # API Gateway requires `x-amazon-apigateway-authtype: custom` on
          # apiKey schemes with an x-amazon-apigateway-authorizer — without
          # it, ImportRestApi silently drops the securityScheme AND every
          # per-op `security` reference to it, leaving every route with
          # authType: NONE. Smithy emits it in the merged spec; this
          # transformation must preserve it verbatim.
          name => {
            type                              = "apiKey"
            name                              = "Authorization"
            in                                = "header"
            "x-amazon-apigateway-authtype"    = try(scheme["x-amazon-apigateway-authtype"], "custom")
            "x-amazon-apigateway-authorizer" = merge(scheme["x-amazon-apigateway-authorizer"], {
              authorizerUri         = local.authorizer_invoke_uri
              authorizerCredentials = aws_iam_role.authorizer_invoke.arn
            })
          }
          if try(scheme["x-amazon-apigateway-authorizer"], null) != null
        },
        {
          for name, scheme in try(local.merged_spec_raw.components.securitySchemes, {}) :
          name => scheme
          if try(scheme["x-amazon-apigateway-authorizer"], null) == null
        },
      )
    })
    info = merge(local.merged_spec_raw.info, {
      description = "Context Ontology Accelerator REST API — namespace, ingestion, and query management."
    })
  })

  # Every unique Lambda ARN the API Gateway needs invoke permission on.
  unique_lambda_arns = distinct(concat(
    [aws_lambda_function.stub.arn],
    values(var.path_handlers),
  ))

  # MethodSettings for expensive-op throttle overrides. Include ONLY
  # ops whose path+method actually exists in the served spec (matches
  # CDK's stale-entry skip).
  expensive_method_settings = {
    for op in var.expensive_api_operations :
    "${trimprefix(op.path, "/")}/${op.method}" => {
      throttling_rate_limit  = var.expensive_throttle_rate_limit
      throttling_burst_limit = var.expensive_throttle_burst_limit
    }
    if(
      contains(keys(local.merged_spec_raw.paths), op.path) &&
      contains(keys(try(local.merged_spec_raw.paths[op.path], {})), lower(op.method))
    )
  }
}
