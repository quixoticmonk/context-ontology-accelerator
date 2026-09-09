# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# 501 "Not Implemented" stub Lambda — target for any Smithy-defined
# path not wired to a real handler via path_handlers. The authorizer
# still protects these routes (unless in unsecured_paths).

resource "aws_iam_role" "stub" {
  name               = "${local.stub_name}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "stub_basic" {
  role       = aws_iam_role.stub.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Inline zip built from the same three lines as CDK's Code.fromInline.
data "archive_file" "stub_source" {
  type        = "zip"
  output_path = "${path.module}/artifacts/stub.zip"

  source {
    filename = "index.py"
    content  = <<-EOT
      import json
      def handler(event, context):
          return {
              "statusCode": 501,
              "headers": {"Content-Type": "application/json"},
              "body": json.dumps({"message": "Not implemented"}),
          }
    EOT
  }
}

resource "aws_lambda_function" "stub" {
  function_name    = local.stub_name
  role             = aws_iam_role.stub.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  filename         = data.archive_file.stub_source.output_path
  source_code_hash = data.archive_file.stub_source.output_base64sha256
  timeout          = 5

  tags = local.tags
}
