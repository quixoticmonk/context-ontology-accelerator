# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Custom Lambda authorizer for the REST API. Validates JWTs (Cognito or
# external OIDC), resolves the caller's roles from DDB, and evaluates
# Cedar policies against the requested resource.

# ── SSM reads (issuer, client id, group claim from auth-idp) ─────────
data "aws_ssm_parameter" "issuer" {
  name = "${var.ssm_prefix}/issuer"
}

data "aws_ssm_parameter" "client_id" {
  name = "${var.ssm_prefix}/userpool-client-id"
}

data "aws_ssm_parameter" "group_claim" {
  name = "${var.ssm_prefix}/authentication-group-token-name"
}

# ── Role + policies ─────────────────────────────────────────────────
resource "aws_iam_role" "authorizer" {
  name               = "${local.authorizer_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "authorizer_vpc" {
  role       = aws_iam_role.authorizer.name
  policy_arn = data.aws_iam_policy.lambda_vpc_access.arn
}

data "aws_iam_policy_document" "authorizer" {
  # Read-only on the three authnz tables + streams.
  statement {
    sid = "AuthnzTablesRead"
    actions = [
      "dynamodb:GetItem", "dynamodb:Query", "dynamodb:BatchGetItem",
    ]
    resources = [
      var.roles_table_arn,
      "${var.roles_table_arn}/index/*",
      var.resource_role_mappings_table_arn,
      "${var.resource_role_mappings_table_arn}/index/*",
      var.cache_invalidation_table_arn,
      "${var.cache_invalidation_table_arn}/index/*",
    ]
  }

  # Least-privilege read of namespace status for the ARCHIVED mutation
  # guard — the authorizer refuses mutations against archived namespaces.
  statement {
    sid       = "NamespaceStatusRead"
    actions   = ["dynamodb:GetItem"]
    resources = [var.namespaces_table_arn]
  }
}

resource "aws_iam_policy" "authorizer" {
  name   = "${local.authorizer_name}-policy"
  policy = data.aws_iam_policy_document.authorizer.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "authorizer" {
  role       = aws_iam_role.authorizer.name
  policy_arn = aws_iam_policy.authorizer.arn
}

# ── Lambda ──────────────────────────────────────────────────────────
resource "aws_lambda_function" "authorizer" {
  function_name    = local.authorizer_name
  role             = aws_iam_role.authorizer.arn
  runtime          = "python3.12"
  handler          = "coa_control_plane.authorization.handler.handler"
  filename         = var.control_plane_zip_path
  source_code_hash = try(filebase64sha256(var.control_plane_zip_path), null)
  timeout          = 10
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      JWKS_ISSUER                       = data.aws_ssm_parameter.issuer.value
      CLIENT_ID                         = data.aws_ssm_parameter.client_id.value
      GROUP_CLAIM_NAME                  = data.aws_ssm_parameter.group_claim.value
      ROLES_TABLE_NAME                  = var.roles_table_name
      RESOURCE_ROLE_MAPPINGS_TABLE_NAME = var.resource_role_mappings_table_name
      CACHE_INVALIDATION_TABLE_NAME     = var.cache_invalidation_table_name
      NAMESPACES_TABLE_NAME             = "${var.name_prefix}-namespaces"
    }
  }

  tags = local.tags
}
