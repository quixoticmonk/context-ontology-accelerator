# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IAM for the database-side sources pipeline. Ordered by role:
#   1. federated_catalog_role   — Glue Connection ROLE_ARN + LF resource role
#   2. federation_provisioner   — the Lambda that creates catalogs
#   3. db_connector             — the discovery Lambda
#   4. db_enrichment_task       — the Fargate enrichment task role
#   5. db_scan_reaper           — terminal-execution safety net Lambda
#   6. db_scan_trigger          — SQS→SFN trigger Lambda
#   7. bulk_review_worker       — async approve/reject worker Lambda
#
# Every statement's rationale is inlined from the CDK source — the
# comments carry the load-bearing security intent (namespace-tag
# conditions, ExternalId requirements, aws:CalledVia guards, and
# fail-closed Deny statements). Do not simplify without reading them.

# ═════════════════════════════════════════════════════════════════════
#  Shared Lambda trust policy + VPC-access managed policy
# ═════════════════════════════════════════════════════════════════════

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "lambda_vpc_access" {
  arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ═════════════════════════════════════════════════════════════════════
#  1. Federated Catalog Role
# ═════════════════════════════════════════════════════════════════════
# Applied as ROLE_ARN on every federated Glue connection AND read by
# Lake Formation to vend credentials for the managed (no-Lambda)
# connector. Trusts BOTH glue and lakeformation service principals.

data "aws_iam_policy_document" "federated_catalog_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = [
        "glue.amazonaws.com",
        "lakeformation.amazonaws.com",
      ]
    }
  }

  # Federation provisioner Lambda role added below (via a companion
  # `aws_iam_role_policy` on the OTHER role's trust — but trust policy
  # is on this role. Use single unified doc.
  statement {
    sid     = "FederationProvisionerAssume"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.federation_provisioner.arn]
    }
  }
}

resource "aws_iam_role" "federated_catalog" {
  name               = "${var.name_prefix}-federated-catalog-role"
  assume_role_policy = data.aws_iam_policy_document.federated_catalog_trust.json
  tags               = local.tags
}

data "aws_iam_policy_document" "federated_catalog" {
  # Spill bucket read/write (Athena federation writes here).
  statement {
    sid = "SpillBucketAccess"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket",
      "s3:AbortMultipartUpload", "s3:ListMultipartUploadParts",
    ]
    resources = [
      var.athena_spill_bucket_arn,
      "${var.athena_spill_bucket_arn}/*",
    ]
  }

  # Glue connection read on the federated catalog namespace.
  statement {
    sid     = "GlueConnectionRead"
    actions = ["glue:GetConnection"]
    resources = [
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:connection/${local.federated_catalog_prefix}*",
    ]
  }

  # glue:ManagedConnector does not support resource-level restrictions
  # (AWS limitation).
  statement {
    sid       = "GlueManagedConnectorExecution"
    actions   = ["glue:ManagedConnector"]
    resources = ["*"]
  }

  # Read the credential secret AS this role. Two statements — tag
  # condition only applies in-account.
  #
  # (1) In-account secrets must carry a `{prefix}:namespace` tag.
  #     Same tag-EXISTS reduction as the discovery role (shared role,
  #     exact binding is at registration and on the serve resource
  #     policy).
  statement {
    sid     = "ReadCredentialSecretInAccount"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      "arn:${data.aws_partition.current.partition}:secretsmanager:*:*:secret:*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "Null"
      variable = "secretsmanager:ResourceTag/${var.namespace_tag_key}"
      values   = ["false"]
    }
  }

  # (2) Cross-account secrets (customer's own secret) can't carry a tag
  # we control, so they stay unconditioned here — access is gated by
  # the secret's resource policy, which the customer grants to this role.
  # Require aws:ResourceAccount to be POPULATED so a request context
  # without a resolved account can't satisfy StringNotEquals as absent.
  statement {
    sid     = "ReadCredentialSecretCrossAccount"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      "arn:${data.aws_partition.current.partition}:secretsmanager:*:*:secret:*",
    ]

    condition {
      test     = "StringNotEquals"
      variable = "aws:ResourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "Null"
      variable = "aws:ResourceAccount"
      values   = ["false"]
    }
  }

  # Decrypt CMK-encrypted secrets. kms:ViaService confines this to
  # Secrets-Manager-mediated decrypts so the role can't use it for
  # any other KMS operation.
  statement {
    sid       = "DecryptCredentialSecret"
    actions   = ["kms:Decrypt"]
    resources = ["*"]

    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["secretsmanager.*.amazonaws.com"]
    }
  }

  # ec2:Describe* — read-only, no resource-level scoping supported.
  statement {
    sid = "Ec2NetworkDescribe"
    actions = [
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeVpcs",
      "ec2:DescribeRouteTables",
      "ec2:DescribeAvailabilityZones",
    ]
    resources = ["*"]
  }

  # Mutating ENI actions — MUST be `*`, not resource-scoped.
  # Glue's managed connector runs a pre-flight authorization check that
  # authorizes against the wildcard resource. See the CDK comment for
  # the CloudTrail evidence and the AWS-managed AWSGlueServiceRole
  # precedent — this matches the documented service contract.
  statement {
    sid = "Ec2NetworkInterfaceManagement"
    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:DeleteNetworkInterface",
      "ec2:CreateTags",
    ]
    resources = ["*"]
  }

  # ec2:CreateNetworkInterfacePermission — required for Glue managed/VPC
  # connections. Scoped by ec2:AuthorizedService to Glue so the role
  # cannot hand ENI-attach permission to an arbitrary service.
  statement {
    sid     = "Ec2CreateNetworkInterfacePermissionForGlue"
    actions = ["ec2:CreateNetworkInterfacePermission"]
    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:network-interface/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:AuthorizedService"
      values   = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "federated_catalog" {
  name   = "${var.name_prefix}-federated-catalog-policy"
  policy = data.aws_iam_policy_document.federated_catalog.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "federated_catalog" {
  role       = aws_iam_role.federated_catalog.name
  policy_arn = aws_iam_policy.federated_catalog.arn
}

# ═════════════════════════════════════════════════════════════════════
#  2. Federation Provisioner Role
# ═════════════════════════════════════════════════════════════════════
# Runs the Lambda that creates Glue Connections, federated Glue
# catalogs, and Lake Formation grants. Trusted by lambda.amazonaws.com
# AND by dbConnectorFn's role (self-heal path — see connector IAM).
#
# LAKE FORMATION ADMIN: this role must be registered as an LF
# data-lake admin non-destructively (append-only). That registration
# is performed in sub-turn 4 via a custom-resource pattern.

data "aws_iam_policy_document" "federation_provisioner_trust" {
  statement {
    sid     = "LambdaService"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }

  statement {
    sid     = "DbConnectorSelfHealAssume"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.db_connector.arn]
    }
  }

  # Sources API assumes this role at delete-source time to run the
  # federation teardown as a Lake Formation admin (see sources_api.tf).
  statement {
    sid     = "SourcesApiTeardownAssume"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.sources_api.arn]
    }
  }
}

resource "aws_iam_role" "federation_provisioner" {
  name               = "${var.name_prefix}-sources-federation-provisioner-role"
  assume_role_policy = data.aws_iam_policy_document.federation_provisioner_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "federation_provisioner_vpc" {
  role       = aws_iam_role.federation_provisioner.name
  policy_arn = data.aws_iam_policy.lambda_vpc_access.arn
}

data "aws_iam_policy_document" "federation_provisioner" {
  statement {
    sid = "SourcesTableAccess"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [
      aws_dynamodb_table.sources.arn,
      "${aws_dynamodb_table.sources.arn}/index/*",
    ]
  }

  statement {
    sid = "SpillBucketAccess"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket",
    ]
    resources = [
      var.athena_spill_bucket_arn,
      "${var.athena_spill_bucket_arn}/*",
    ]
  }

  # Glue Connections — created per source under the sanitized prefix.
  statement {
    sid = "GlueConnectionManagement"
    actions = [
      "glue:CreateConnection",
      "glue:DeleteConnection",
      "glue:GetConnection",
      "glue:UpdateConnection",
      "glue:PassConnection",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:connection/${local.federated_catalog_prefix}*",
    ]
  }

  # Glue federated catalog management — one managed catalog per source.
  statement {
    sid = "GlueFederatedCatalogManagement"
    actions = [
      "glue:CreateCatalog",
      "glue:DeleteCatalog",
      "glue:GetCatalog",
      "glue:GetDatabase",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog/${local.federated_catalog_prefix}*",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:database/${local.federated_catalog_prefix}*/*",
    ]
  }

  # Read federated catalog for LF grants.
  statement {
    sid = "GlueFederatedCatalogRead"
    actions = [
      "glue:GetDatabase", "glue:GetDatabases",
      "glue:GetTable", "glue:GetTables",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog/${local.federated_catalog_prefix}*",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:database/${local.federated_catalog_prefix}*",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:table/${local.federated_catalog_prefix}*",
    ]
  }

  # Native Glue databases (GLUE_DATABASE / S3-Iceberg sources) —
  # required for LF grant on native databases.
  statement {
    sid = "GlueNativeDatabaseRead"
    actions = [
      "glue:GetDatabase", "glue:GetDatabases",
      "glue:GetTable", "glue:GetTables",
      "glue:GetTags",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:database/*",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:table/*/*",
    ]
  }

  # Lake Formation federation ops — no resource-level scoping.
  statement {
    sid = "LakeFormationFederation"
    actions = [
      "lakeformation:RegisterResource",
      "lakeformation:DeregisterResource",
      "lakeformation:DescribeResource",
      "lakeformation:GrantPermissions",
    ]
    resources = ["*"]
  }

  # Consumer query role ARN (serve runtime role) is read at provision
  # time to scope the LF grant. SSM param written by the serve module.
  statement {
    sid     = "ReadConsumerQueryRoleParam"
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:${data.aws_partition.current.partition}:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_prefix}/serve/runtime-role-arn",
    ]
  }

  # Attach a resource policy to a customer secret so the consumer query
  # principal can read it. Restricted to secrets ALREADY onboarded to a
  # namespace (tag-EXISTS) — otherwise this is an unrestricted write
  # primitive over every in-account secret.
  statement {
    sid = "SecretResourcePolicyForConsumer"
    actions = [
      "secretsmanager:GetResourcePolicy",
      "secretsmanager:PutResourcePolicy",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:secretsmanager:*:*:secret:*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "Null"
      variable = "secretsmanager:ResourceTag/${var.namespace_tag_key}"
      values   = ["false"]
    }
  }

  # Metadata-only read of the credential secret's tags — deliberately
  # NOT GetSecretValue. The readability precheck reads the secret AS
  # the federated_catalog_role instead.
  statement {
    sid       = "DescribeSecretForNamespaceBinding"
    actions   = ["secretsmanager:DescribeSecret"]
    resources = ["arn:${data.aws_partition.current.partition}:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:*"]
  }

  # Pass the federated_catalog_role to Glue + LF. Cannot carry
  # PassedToService AND GetRole in the same statement.
  statement {
    sid       = "PassFederatedCatalogRole"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.federated_catalog.arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["glue.amazonaws.com", "lakeformation.amazonaws.com"]
    }
  }

  statement {
    sid       = "GetFederatedCatalogRole"
    actions   = ["iam:GetRole"]
    resources = [aws_iam_role.federated_catalog.arn]
  }
}

resource "aws_iam_policy" "federation_provisioner" {
  name   = "${var.name_prefix}-sources-federation-provisioner-policy"
  policy = data.aws_iam_policy_document.federation_provisioner.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "federation_provisioner" {
  role       = aws_iam_role.federation_provisioner.name
  policy_arn = aws_iam_policy.federation_provisioner.arn
}

# SSM parameter identifying the LF admin. Sub-turn 4's custom resource
# reads this to append the role ARN to LF DataLakeAdmins.
resource "aws_ssm_parameter" "federation_provisioner_role_arn" {
  name        = "${var.ssm_prefix}/sources/federation-provisioner-role-arn"
  type        = "String"
  value       = aws_iam_role.federation_provisioner.arn
  description = "Role that must be a Lake Formation data-lake admin to provision federated catalogs"
  tags        = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  3. DB Connector (Discovery) Role
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "db_connector" {
  name               = "${var.name_prefix}-sources-db-connector-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "db_connector_vpc" {
  role       = aws_iam_role.db_connector.name
  policy_arn = data.aws_iam_policy.lambda_vpc_access.arn
}

data "aws_iam_policy_document" "db_connector" {
  statement {
    sid = "SourcesTableAccess"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [
      aws_dynamodb_table.sources.arn,
      "${aws_dynamodb_table.sources.arn}/index/*",
      aws_dynamodb_table.source_scan_jobs.arn,
      "${aws_dynamodb_table.source_scan_jobs.arn}/index/*",
    ]
  }

  statement {
    sid       = "NamespacesTableRead"
    actions   = ["dynamodb:GetItem", "dynamodb:Query"]
    resources = [var.namespaces_table_arn]
  }

  statement {
    sid       = "AssumeProjectAccessRole"
    actions   = ["sts:AssumeRole"]
    resources = [var.smus_project_access_role_arn]
  }

  # Glue catalog access — same-account, deployment region only.
  statement {
    sid = "GlueCatalogAccess"
    actions = [
      "glue:GetDatabase", "glue:GetDatabases",
      "glue:GetTable", "glue:GetTables",
      "glue:GetPartitions",
      "glue:GetConnection",
      # Nested/federated Glue catalogs (catalogId "account:catalogName")
      # authorize GetDatabase/GetTables against the nested-catalog resource
      # itself, not just its children — without these a federated source
      # fails discovery with AccessDenied on `catalog/<name>` (issue 118).
      "glue:GetCatalog",
      "glue:GetCatalogs",
      "glue:GetTags",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog",
      # The nested-catalog resource federated reads authorize against.
      # Account-wide because catalog names arrive per-source at runtime and
      # are not knowable at synth; mirrors the federation-provisioner and
      # serve grants. Actions stay read-only.
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog/*",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:database/*",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:table/*/*",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:connection/*",
    ]
  }

  # Athena enum-value sampling (SELECT DISTINCT).
  statement {
    sid = "AthenaEnumSampling"
    actions = [
      "athena:StartQueryExecution", "athena:GetQueryExecution",
      "athena:GetQueryResults", "athena:StopQueryExecution",
      "athena:GetWorkGroup",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:athena:${var.region}:${data.aws_caller_identity.current.account_id}:workgroup/*",
    ]
  }

  # Custom connector catalog resolution — only our own catalogs.
  statement {
    sid     = "CustomConnectorCatalogRead"
    actions = ["athena:GetDataCatalog"]
    resources = [
      "arn:${data.aws_partition.current.partition}:athena:${var.region}:${data.aws_caller_identity.current.account_id}:datacatalog/${local.federated_catalog_prefix}*",
    ]
  }

  # Invoke a customer-authored Athena federation connector — only when
  # Athena is the caller (aws:CalledVia guard) AND the connector Lambda
  # carries the CONNECTOR_TAG_KEY tag. Wildcards on account by design
  # (customer's account isn't knowable at synth); tag closes the gap.
  statement {
    sid       = "AthenaFederationConnectorInvoke"
    actions   = ["lambda:InvokeFunction"]
    resources = ["arn:${data.aws_partition.current.partition}:lambda:${var.region}:*:function:*"]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:CalledVia"
      values   = ["athena.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/${var.resource_prefix}:connector"
      values   = ["true"]
    }
  }

  # CLOSED: Athena UDF pointed at any same-account function lacking
  # the tag. Fail-closed via StringNotEquals on absent tag. Prevents
  # escalation into the federation provisioner (which holds LF admin).
  # Read the CDK comment before touching this.
  statement {
    sid       = "DenyAthenaInvokeOfUntaggedFunctions"
    effect    = "Deny"
    actions   = ["lambda:InvokeFunction"]
    resources = ["arn:${data.aws_partition.current.partition}:lambda:*:${data.aws_caller_identity.current.account_id}:function:*"]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:CalledVia"
      values   = ["athena.amazonaws.com"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:ResourceTag/${var.resource_prefix}:connector"
      values   = ["true"]
    }
  }

  # LF data access for governed Glue tables (ignored in
  # IAM_ALLOWED_PRINCIPALS accounts).
  statement {
    sid       = "LakeFormationSelectForSampling"
    actions   = ["lakeformation:GetDataAccess"]
    resources = ["*"]
  }

  # Athena spill bucket R/W + sources-data bucket read (Glue sources
  # backed by sources-data need read).
  statement {
    sid = "SpillAndSourcesBucketAccess"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket",
      "s3:AbortMultipartUpload",
    ]
    resources = [
      var.athena_spill_bucket_arn,
      "${var.athena_spill_bucket_arn}/*",
      aws_s3_bucket.sources_data.arn,
      "${aws_s3_bucket.sources_data.arn}/*",
    ]
  }

  # Self-heal path: assume the federation provisioner (LF admin) to
  # grant this Lambda DESCRIBE on a target DB in strict-LF accounts.
  # Scoped to the single role; the connector gains no standing LF admin.
  statement {
    sid       = "AssumeLfGrantorForSelfHeal"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.federation_provisioner.arn]
  }

  # In-account credential secret access — tag-gated so an untagged
  # secret (any random secret in this account) is not readable.
  statement {
    sid       = "SecretsManagerCustomerProvided"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["arn:${data.aws_partition.current.partition}:secretsmanager:*:*:secret:*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "Null"
      variable = "secretsmanager:ResourceTag/${var.namespace_tag_key}"
      values   = ["false"]
    }
  }

  # Read the secret's tags at scan-time (metadata only, not the value).
  statement {
    sid       = "DescribeSecretForNamespaceBinding"
    actions   = ["secretsmanager:DescribeSecret"]
    resources = ["arn:${data.aws_partition.current.partition}:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:*"]
  }

  # Assume cross-account customer-provided datasource-access roles.
  # ExternalId REQUIRED (fail-closed on absent) so a regression in the
  # connector code can't silently widen access.
  statement {
    sid       = "AssumeRoleCoaManaged"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:${data.aws_partition.current.partition}:iam::*:role/${var.name_prefix}-datasource-access-*"]

    condition {
      test     = "Null"
      variable = "sts:ExternalId"
      values   = ["false"]
    }
  }
}

resource "aws_iam_policy" "db_connector" {
  name   = "${var.name_prefix}-sources-db-connector-policy"
  policy = data.aws_iam_policy_document.db_connector.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "db_connector" {
  role       = aws_iam_role.db_connector.name
  policy_arn = aws_iam_policy.db_connector.arn
}

# ═════════════════════════════════════════════════════════════════════
#  4. DB Enrichment Task Role + Execution Role
# ═════════════════════════════════════════════════════════════════════

data "aws_iam_policy_document" "ecs_tasks_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "db_enrichment_execution" {
  name               = "${var.name_prefix}-sources-db-enrichment-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "db_enrichment_execution" {
  role       = aws_iam_role.db_enrichment_execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "db_enrichment_task" {
  name               = "${var.name_prefix}-sources-db-enrichment-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_trust.json
  tags               = local.tags
}

data "aws_iam_policy_document" "db_enrichment_task" {
  statement {
    sid = "SourcesTables"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [
      aws_dynamodb_table.sources.arn,
      "${aws_dynamodb_table.sources.arn}/index/*",
      aws_dynamodb_table.source_scan_jobs.arn,
      "${aws_dynamodb_table.source_scan_jobs.arn}/index/*",
    ]
  }

  statement {
    sid       = "NamespacesRead"
    actions   = ["dynamodb:GetItem", "dynamodb:Query"]
    resources = [var.namespaces_table_arn]
  }

  statement {
    sid       = "AssumeProjectAccessRole"
    actions   = ["sts:AssumeRole"]
    resources = [var.smus_project_access_role_arn]
  }

  statement {
    sid     = "BedrockInvokeModel"
    actions = ["bedrock:InvokeModel"]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*",
      "arn:${data.aws_partition.current.partition}:bedrock:*:${data.aws_caller_identity.current.account_id}:inference-profile/*",
    ]
  }

  # Guardrail enforcement + SSM read that resolves the guardrail ID.
  statement {
    sid     = "BedrockApplyGuardrail"
    actions = ["bedrock:ApplyGuardrail"]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:${var.region}:${data.aws_caller_identity.current.account_id}:guardrail/*",
    ]
  }

  statement {
    sid     = "GuardrailIdSsm"
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:${data.aws_partition.current.partition}:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_prefix}/bedrock/guardrail-id",
    ]
  }

  # Guardrail decision metrics.
  statement {
    sid       = "CloudwatchGuardrailMetrics"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["COA/Guardrails"]
    }
  }

  # In-account datasource-* credential secret — tag-gated.
  statement {
    sid     = "ReadNamespaceBoundCredentialSecret"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      "arn:${data.aws_partition.current.partition}:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}-datasource-*",
    ]

    condition {
      test     = "Null"
      variable = "secretsmanager:ResourceTag/${var.namespace_tag_key}"
      values   = ["false"]
    }
  }

  # Customer-provided cross-account datasource-access role — ExternalId
  # required (fail-closed).
  statement {
    sid       = "AssumeRoleCustomerProvided"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:${data.aws_partition.current.partition}:iam::*:role/${var.name_prefix}-datasource-access-*"]

    condition {
      test     = "Null"
      variable = "sts:ExternalId"
      values   = ["false"]
    }
  }

  statement {
    sid = "EnrichmentGlueCatalogAccess"
    actions = [
      "glue:GetTable", "glue:GetTables",
      "glue:GetDatabase", "glue:GetConnection",
      # Nested/federated catalogs authorize against the catalog resource
      # itself — same gap as discovery (issue 118).
      "glue:GetCatalog",
      "glue:GetCatalogs",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog/*",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:database/*",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:table/*/*",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:connection/*",
    ]
  }
}

resource "aws_iam_policy" "db_enrichment_task" {
  name   = "${var.name_prefix}-sources-db-enrichment-task-policy"
  policy = data.aws_iam_policy_document.db_enrichment_task.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "db_enrichment_task" {
  role       = aws_iam_role.db_enrichment_task.name
  policy_arn = aws_iam_policy.db_enrichment_task.arn
}

# ═════════════════════════════════════════════════════════════════════
#  5. DB Scan Reaper Role
# ═════════════════════════════════════════════════════════════════════
# Terminal-execution safety net: writes SCAN_FAILED on the sources
# table when the SFN times out / aborts / fails without a catchable
# error.

resource "aws_iam_role" "db_scan_reaper" {
  name               = "${var.name_prefix}-sources-db-scan-reaper-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "db_scan_reaper_vpc" {
  role       = aws_iam_role.db_scan_reaper.name
  policy_arn = data.aws_iam_policy.lambda_vpc_access.arn
}

data "aws_iam_policy_document" "db_scan_reaper" {
  statement {
    sid = "SourcesTableAccess"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "dynamodb:Query",
    ]
    resources = [
      aws_dynamodb_table.sources.arn,
      "${aws_dynamodb_table.sources.arn}/index/*",
    ]
  }
}

resource "aws_iam_policy" "db_scan_reaper" {
  name   = "${var.name_prefix}-sources-db-scan-reaper-policy"
  policy = data.aws_iam_policy_document.db_scan_reaper.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "db_scan_reaper" {
  role       = aws_iam_role.db_scan_reaper.name
  policy_arn = aws_iam_policy.db_scan_reaper.arn
}

# ═════════════════════════════════════════════════════════════════════
#  6. DB Scan Trigger Role
# ═════════════════════════════════════════════════════════════════════
# SQS → SFN trigger. Starts execution; SQS event-source poll grants
# added by the vpc-access managed policy + explicit SQS grants below.

resource "aws_iam_role" "db_scan_trigger" {
  name               = "${var.name_prefix}-sources-db-scan-trigger-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "db_scan_trigger_vpc" {
  role       = aws_iam_role.db_scan_trigger.name
  policy_arn = data.aws_iam_policy.lambda_vpc_access.arn
}

data "aws_iam_policy_document" "db_scan_trigger" {
  # SQS event-source polling — required for aws_lambda_event_source_mapping.
  statement {
    sid = "SqsPolling"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
    ]
    resources = [aws_sqs_queue.db_scan.arn]
  }

  statement {
    sid       = "StartStateMachine"
    actions   = ["states:StartExecution"]
    resources = [aws_sfn_state_machine.db_scan.arn]
  }
}

resource "aws_iam_policy" "db_scan_trigger" {
  name   = "${var.name_prefix}-sources-db-scan-trigger-policy"
  policy = data.aws_iam_policy_document.db_scan_trigger.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "db_scan_trigger" {
  role       = aws_iam_role.db_scan_trigger.name
  policy_arn = aws_iam_policy.db_scan_trigger.arn
}

# ═════════════════════════════════════════════════════════════════════
#  7. Bulk Review Worker Role
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "bulk_review_worker" {
  name               = "${var.name_prefix}-sources-bulk-review-worker-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "bulk_review_worker_vpc" {
  role       = aws_iam_role.bulk_review_worker.name
  policy_arn = data.aws_iam_policy.lambda_vpc_access.arn
}

data "aws_iam_policy_document" "bulk_review_worker" {
  statement {
    sid = "SourcesTableAccess"
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "dynamodb:Query",
    ]
    resources = [
      aws_dynamodb_table.sources.arn,
      "${aws_dynamodb_table.sources.arn}/index/*",
    ]
  }

  statement {
    sid       = "NamespacesRead"
    actions   = ["dynamodb:GetItem", "dynamodb:Query"]
    resources = [var.namespaces_table_arn]
  }

  statement {
    sid       = "AssumeProjectAccessRole"
    actions   = ["sts:AssumeRole"]
    resources = [var.smus_project_access_role_arn]
  }

  # SQS polling + self-continuation send (the worker re-enqueues to
  # itself to page a large source across invocations).
  statement {
    sid = "SqsPollAndSelfContinuation"
    actions = [
      "sqs:ReceiveMessage",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:SendMessage",
    ]
    resources = [aws_sqs_queue.bulk_review.arn]
  }
}

resource "aws_iam_policy" "bulk_review_worker" {
  name   = "${var.name_prefix}-sources-bulk-review-worker-policy"
  policy = data.aws_iam_policy_document.bulk_review_worker.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "bulk_review_worker" {
  role       = aws_iam_role.bulk_review_worker.name
  policy_arn = aws_iam_policy.bulk_review_worker.arn
}
