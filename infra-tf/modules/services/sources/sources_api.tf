# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Unified sources API Lambda — CRUD for database + document sources,
# review workflow, upload URL signing, teardown orchestration.
# ~20 IAM statements matching the CDK exactly.

# ═════════════════════════════════════════════════════════════════════
#  IAM
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "sources_api" {
  name               = "${var.name_prefix}-sources-api-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "sources_api_vpc" {
  role       = aws_iam_role.sources_api.name
  policy_arn = data.aws_iam_policy.lambda_vpc_access.arn
}

data "aws_iam_policy_document" "sources_api" {
  # The only `resources = ["*"]` in this document is ReadSourceBucketTags
  # (s3:GetBucketTagging), where the customer-provided bucket isn't
  # knowable at synth. That statement is deliberately metadata-only —
  # the API does NOT get s3:GetObject anywhere on the source bucket.
  # checkov:skip=CKV_AWS_356:ReadSourceBucketTags wildcard is required because customer source buckets are unknown at synth; s3:GetObject is deliberately not granted.
  # checkov:skip=CKV_AWS_111:s3:GetBucketTagging is metadata-only; the API cannot read customer bucket contents.
  # DDB read/write on sources + source-scan-jobs + namespaces.
  statement {
    sid = "SourcesAndJobsTables"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan",
      "dynamodb:BatchGetItem", "dynamodb:BatchWriteItem",
      "dynamodb:TransactWriteItems",
    ]
    resources = [
      aws_dynamodb_table.sources.arn,
      "${aws_dynamodb_table.sources.arn}/index/*",
      aws_dynamodb_table.source_scan_jobs.arn,
      "${aws_dynamodb_table.source_scan_jobs.arn}/index/*",
    ]
  }

  statement {
    sid = "NamespacesTableAccess"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "dynamodb:Query",
    ]
    resources = [var.namespaces_table_arn]
  }

  # SQS SendMessage to all three primary queues.
  statement {
    sid     = "SqsSend"
    actions = ["sqs:SendMessage", "sqs:GetQueueAttributes"]
    resources = [
      aws_sqs_queue.db_scan.arn,
      aws_sqs_queue.doc_ingestion.arn,
      aws_sqs_queue.bulk_review.arn,
    ]
  }

  # Start the doc-deletion state machine.
  statement {
    sid       = "StartDocDeletion"
    actions   = ["states:StartExecution"]
    resources = [aws_sfn_state_machine.doc_deletion.arn]
  }

  # Assume the shared DataZone project access role.
  statement {
    sid       = "AssumeProjectAccessRole"
    actions   = ["sts:AssumeRole"]
    resources = [var.smus_project_access_role_arn]
  }

  # Registration verifies that a caller-named source bucket carries
  # the `{prefix}:namespace` tag. GetBucketTagging on `*` — the wildcard is
  # deliberate (customer's bucket isn't knowable at synth); the API
  # deliberately does NOT get s3:GetObject.
  statement {
    sid       = "ReadSourceBucketTags"
    actions   = ["s3:GetBucketTagging"]
    resources = ["*"]
  }

  # On delete, sources-api assumes the federation provisioner's role
  # (LF admin) to run teardown. The reverse trust is added on the
  # federation_provisioner role's assume_role_policy — see iam_db.tf.
  statement {
    sid       = "AssumeFederationProvisionerRole"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.federation_provisioner.arn]
  }

  # DataZone Search/Get/Delete for the tables tab + source deletion.
  statement {
    sid = "DataZoneAccess"
    actions = [
      "datazone:Search",
      "datazone:GetAsset",
      "datazone:DeleteAsset",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:datazone:${var.region}:${data.aws_caller_identity.current.account_id}:domain/${var.smus_domain_id}",
      "arn:${data.aws_partition.current.partition}:datazone:${var.region}:${data.aws_caller_identity.current.account_id}:domain/${var.smus_domain_id}/*",
    ]
  }

  # Glue namespace-ownership check at source-create. Both actions are
  # required — glue:GetTags on a database ARN authorizes against
  # glue:GetDatabase on the catalog, so tag-only would refuse every
  # legitimate source. See the CDK comment on this statement — the
  # residual "read database metadata account-wide" is the AWS minimum
  # for reading the authorization tag.
  statement {
    sid     = "GlueOwnershipTagRead"
    actions = ["glue:GetTags", "glue:GetDatabase"]
    resources = [
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:database/*",
    ]
  }

  # Athena data-catalog lifecycle for CUSTOM_CONNECTOR sources. Scoped
  # to the sanitized federated catalog prefix so this reaches only
  # catalogs this deployment created.
  statement {
    sid = "AthenaDataCatalogLifecycle"
    actions = [
      "athena:CreateDataCatalog",
      "athena:DeleteDataCatalog",
      "athena:GetDataCatalog",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:athena:${var.region}:${data.aws_caller_identity.current.account_id}:datacatalog/${local.federated_catalog_prefix}*",
    ]
  }

  # Pre-signed PUT URLs for document uploads. Scoped to <ns>/raw/*.
  statement {
    sid       = "SignPresignedUploadPuts"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.sources_data.arn}/*/raw/*"]
  }

  # Re-scan backup blob: the tables API reads the pre-rescan pre-image
  # to render the old-vs-new diff panel and the removed-item sets
  # under RESCAN_REVIEW, and rewrites it when a steward keeps a
  # flagged removal. Without GetObject here the diff read fails closed
  # (rescan_diff_backup_read_failed) and the diff panel never renders.
  statement {
    sid       = "RescanBackupReadWrite"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.sources_data.arn}/*/rescan-backup/*"]
  }

  # S3 reports a missing key as NoSuchKey only to a caller that also
  # holds ListBucket on the bucket; without it, GetObject on an absent
  # key returns AccessDenied instead. An absent backup blob is a
  # NORMAL state — a re-scan that finds no drift writes none, yet
  # still lands the source in RESCAN_REVIEW — so the read helper's
  # absent-key branch has to be able to fire. Lacking this grant, that
  # branch is unreachable in a deployed environment and the tables
  # page 500s for every no-drift re-scan.
  #
  # Scoped to the bucket ARN with no s3:prefix condition: the
  # condition governs ListObjects calls, and GetObject's 403-vs-404
  # choice is not guaranteed to honour it, so a prefix-scoped grant
  # risks looking like a fix while leaving the 500 in place. The grant
  # conveys only "may list this bucket", which the two other roles
  # touching this bucket already hold.
  statement {
    sid       = "SourcesBucketList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.sources_data.arn]
  }

  # Namespace-binding check for JDBC credential secrets at registration.
  # Metadata only — deliberately NOT GetSecretValue. The API reads the
  # secret's TAGS to require a `{prefix}:namespace` tag listing the
  # registering namespace, so a source can only be registered against a
  # credential secret bound to its own namespace.
  statement {
    sid     = "DescribeSecretForNamespaceBinding"
    actions = ["secretsmanager:DescribeSecret"]
    # Region-wildcard in-account: cross-account secrets are gated by
    # the customer's resource policy + assume-role, not by tags this
    # deployment cannot set.
    resources = ["arn:${data.aws_partition.current.partition}:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:*"]
  }
}

resource "aws_iam_policy" "sources_api" {
  name   = "${var.name_prefix}-sources-api-policy"
  policy = data.aws_iam_policy_document.sources_api.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "sources_api" {
  role       = aws_iam_role.sources_api.name
  policy_arn = aws_iam_policy.sources_api.arn
}

# ═════════════════════════════════════════════════════════════════════
#  Lambda function
# ═════════════════════════════════════════════════════════════════════

resource "aws_lambda_function" "sources_api" {
  function_name    = "${var.name_prefix}-sources-api"
  role             = aws_iam_role.sources_api.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "coa_sources.api.sources_handler.handler"
  filename         = var.sources_zip_path
  source_code_hash = local.sources_zip_hash
  timeout          = 30
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      SOURCES_TABLE                   = aws_dynamodb_table.sources.name
      SOURCE_SCAN_JOBS_TABLE          = aws_dynamodb_table.source_scan_jobs.name
      NAMESPACES_TABLE                = var.namespaces_table_name
      SCAN_QUEUE_URL                  = aws_sqs_queue.db_scan.url
      INGESTION_QUEUE_URL             = aws_sqs_queue.doc_ingestion.url
      REVIEW_QUEUE_URL                = aws_sqs_queue.bulk_review.url
      BUCKET_NAME                     = aws_s3_bucket.sources_data.bucket
      DELETION_STATE_MACHINE_ARN      = aws_sfn_state_machine.doc_deletion.arn
      ALLOWED_ORIGIN                  = var.allowed_origin
      SMUS_DOMAIN_ID                  = var.smus_domain_id
      PROJECT_ACCESS_ROLE_ARN         = var.smus_project_access_role_arn
      FEDERATION_PROVISIONER_ROLE_ARN = aws_iam_role.federation_provisioner.arn
      RESOURCE_PREFIX                 = "${var.name_prefix}-"
      # BARE prefix (not `{prefix}-{env}-`) — keys the `{prefix}:namespace`
      # tag on every resource this role checks at registration. Must
      # equal the prefix in `namespace_tag_key` above.
      RESOURCE_TAG_PREFIX = var.resource_prefix
    }
  }

  tags = local.tags
}

