# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Idempotency-record access for retry-safe create operations.
#
# CreateSource (sources API) is retry-safe.
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
  name   = "${var.name_prefix}-sources-idempotency"
  policy = data.aws_iam_policy_document.idempotency.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "sources_api_idempotency" {
  role       = aws_iam_role.sources_api.name
  policy_arn = aws_iam_policy.idempotency.arn
}
