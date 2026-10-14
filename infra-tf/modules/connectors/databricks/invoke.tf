# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Query-principal grants: three permissions per role in `query_role_arns`:
#   1. lambda:InvokeFunction on the connector Lambda
#   2. s3:GetObject on the spill prefix
#   3. kms:Decrypt on the spill CMK
#
# Each principal is granted deliberately. The CDK's `grantInvoke` dedupes
# by principal; Terraform's `for_each` on the set gives the same shape.

resource "aws_lambda_permission" "invoke" {
  for_each = toset(var.query_role_arns)

  statement_id  = "QueryInvoke${substr(sha256(each.value), 0, 8)}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = each.value
}

# Spill bucket policy: allow each query principal to GetObject on the
# spill prefix. Rendered as one policy with one statement per principal
# to keep the bucket policy under its 20KB limit if the query principal
# list grows.
data "aws_iam_policy_document" "spill_bucket" {
  source_policy_documents = [data.aws_iam_policy_document.spill_bucket_tls_only.json]

  dynamic "statement" {
    for_each = toset(var.query_role_arns)

    content {
      sid       = "QuerySpillRead${substr(sha256(statement.value), 0, 8)}"
      effect    = "Allow"
      actions   = ["s3:GetObject"]
      resources = ["${aws_s3_bucket.spill.arn}/${local.spill_prefix_glob}"]
      principals {
        type        = "AWS"
        identifiers = [statement.value]
      }
    }
  }
}

# Override the bucket policy from spill.tf with this richer version when
# `query_role_arns` is non-empty. When it's empty, this document reduces
# to the TLS-only policy and the override is a no-op.
resource "aws_s3_bucket_policy" "spill_with_invokers" {
  count = length(var.query_role_arns) > 0 ? 1 : 0

  bucket     = aws_s3_bucket.spill.id
  policy     = data.aws_iam_policy_document.spill_bucket.json
  depends_on = [aws_s3_bucket_policy.spill] # supersedes
}

# KMS key policy: allow each query principal to Decrypt. A key policy's
# resource is always the key it's attached to ("*" means exactly that).
data "aws_iam_policy_document" "spill_key_policy" {
  statement {
    sid       = "RootAccountAdmin"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid       = "ConnectorGenerateSpillDataKey"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey", "kms:Decrypt", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.this.arn]
    }
  }

  dynamic "statement" {
    for_each = toset(var.query_role_arns)

    content {
      sid       = "QuerySpillDecrypt${substr(sha256(statement.value), 0, 8)}"
      effect    = "Allow"
      actions   = ["kms:Decrypt", "kms:DescribeKey"]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = [statement.value]
      }
    }
  }
}

resource "aws_kms_key_policy" "spill" {
  key_id = aws_kms_key.spill.id
  policy = data.aws_iam_policy_document.spill_key_policy.json
}
