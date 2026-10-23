# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Idempotency-record access for retry-safe create operations.
#
# StartInduction (ontology api-proxy) is retry-safe. The proxy, not the ECS
# service, enforces it because only the proxy sees the caller identity.
# They take an optional caller-supplied `clientToken`; coa_common.idempotency
# records each one in the shared idempotency table (owned by
# foundation/authnz, name/ARN read from SSM by the calling stack). Grants
# exactly the four item actions the helper performs on that table and
# nothing else, and the env var it reads (IDEMPOTENCY_TABLE) is set on each
# function. Without either, a create carrying a clientToken returns 503.
#
# Ported from infra/lib/utils/idempotency.ts grantIdempotencyTable (COA v0.3.7).

data "aws_iam_policy_document" "idempotency" {
  statement {
    sid = "IdempotencyRecords"
    actions = [
      "dynamodb:DeleteItem",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
    ]
    resources = [var.idempotency_table_arn]
  }
}

resource "aws_iam_policy" "idempotency" {
  name   = "${var.name_prefix}-ontology-idempotency"
  policy = data.aws_iam_policy_document.idempotency.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "api_proxy_idempotency" {
  role       = aws_iam_role.api_proxy.name
  policy_arn = aws_iam_policy.idempotency.arn
}
