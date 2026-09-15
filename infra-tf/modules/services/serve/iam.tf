# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# AgentCore Runtime execution role with ~20 policy statements. Every
# statement's rationale mirrors the CDK's `runtime.addToRolePolicy`
# calls — read those comments in serve-stack.ts before changing any of
# these, especially the Athena federation Allow + Deny pair.

data "aws_iam_policy_document" "runtime_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "runtime" {
  name               = "${var.name_prefix}-context-manager-runtime"
  assume_role_policy = data.aws_iam_policy_document.runtime_trust.json
  tags               = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  Runtime policy — single big doc keyed by sid so diffs are auditable
# ═════════════════════════════════════════════════════════════════════
# Residual `resources = ["*"]` statements are all AWS-service
# limitations documented in the AWS Service Authorization Reference:
#   - EcrAuthToken                : ecr:GetAuthorizationToken has no resource type
#   - RedshiftDataApi             : redshift-data actions have no resource type
#   - LakeFormationGetDataAccess  : lakeformation:GetDataAccess has no resource type
# Every other statement in this document is ARN-scoped or condition-gated.
# checkov:skip=CKV_AWS_356:Residual wildcard is limited to EcrAuthToken, RedshiftDataApi, and LakeFormationGetDataAccess. All three have no IAM resource type per the AWS Service Authorization Reference.
# checkov:skip=CKV_AWS_111:Same three statements are read/query actions with no supported resource type; every other write action is ARN-scoped.
data "aws_iam_policy_document" "runtime" {
  # checkov:skip=CKV_AWS_356:Residual wildcard is limited to EcrAuthToken, RedshiftDataApi, and LakeFormationGetDataAccess. All three have no IAM resource type per the AWS Service Authorization Reference.
  # checkov:skip=CKV_AWS_111:Same three statements are read/query actions with no supported resource type; every other write action is ARN-scoped.
  statement {
    sid       = "EcrAuthToken"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrImagePull"
    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
    ]
    resources = [var.ecr_repository_arn]
  }

  statement {
    sid       = "SsmRead"
    actions   = ["ssm:GetParameter"]
    resources = ["arn:${data.aws_partition.current.partition}:ssm:${var.region}:${local.account_id}:parameter${var.ssm_prefix}/*"]
  }

  statement {
    sid = "BedrockInvokeConverseGuardrail"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:Converse",
      "bedrock:ConverseStream",
      "bedrock:ApplyGuardrail",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:*:${local.account_id}:inference-profile/*",
      "arn:${data.aws_partition.current.partition}:bedrock:*::foundation-model/*",
      "arn:${data.aws_partition.current.partition}:bedrock:${var.region}:${local.account_id}:guardrail/*",
    ]
  }

  statement {
    sid       = "NeptuneRead"
    actions   = ["neptune-db:ReadDataViaQuery"]
    resources = [var.neptune_cluster_arn]
  }

  statement {
    sid = "DdbReadOnly"
    actions = [
      "dynamodb:GetItem", "dynamodb:Query", "dynamodb:BatchGetItem",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:dynamodb:${var.region}:${local.account_id}:table/${var.sources_table_name}",
      "arn:${data.aws_partition.current.partition}:dynamodb:${var.region}:${local.account_id}:table/${var.sources_table_name}/index/*",
      var.namespaces_table_arn,
      var.roles_table_arn,
      var.resource_role_mappings_table_arn,
      "${var.resource_role_mappings_table_arn}/index/*",
    ]
  }

  statement {
    sid = "SessionMetadataRW"
    actions = [
      "dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query",
      "dynamodb:DeleteItem", "dynamodb:UpdateItem",
    ]
    resources = [
      aws_dynamodb_table.session_metadata.arn,
      "${aws_dynamodb_table.session_metadata.arn}/index/*",
    ]
  }

  statement {
    sid = "S3OntologyAndAthena"
    actions = [
      "s3:GetObject", "s3:ListBucket", "s3:PutObject",
      "s3:GetBucketLocation", "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts", "s3:DeleteObject",
    ]
    resources = [
      var.ontology_bucket_arn,
      "${var.ontology_bucket_arn}/*",
      "arn:${data.aws_partition.current.partition}:s3:::${var.athena_results_bucket_name}",
      "arn:${data.aws_partition.current.partition}:s3:::${var.athena_results_bucket_name}/*",
      "arn:${data.aws_partition.current.partition}:s3:::${var.name_prefix}-demo-data",
      "arn:${data.aws_partition.current.partition}:s3:::${var.name_prefix}-demo-data/*",
    ]
  }

  statement {
    sid     = "S3PrefixedDataBuckets"
    actions = ["s3:GetObject", "s3:ListBucket", "s3:GetBucketLocation"]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.resource_prefix}-*",
      "arn:${data.aws_partition.current.partition}:s3:::${var.resource_prefix}-*/*",
    ]
  }

  statement {
    sid = "AthenaQuery"
    actions = [
      "athena:StartQueryExecution", "athena:GetQueryExecution",
      "athena:GetQueryResults", "athena:GetWorkGroup",
      "athena:GetDataCatalog",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:athena:${var.region}:${local.account_id}:workgroup/*",
      "arn:${data.aws_partition.current.partition}:athena:${var.region}:${local.account_id}:datacatalog/*",
    ]
  }

  statement {
    sid = "RedshiftDataApi"
    actions = [
      "redshift-data:ExecuteStatement",
      "redshift-data:DescribeStatement",
      "redshift-data:GetStatementResult",
      "redshift-data:ListStatements",
    ]
    # redshift-data doesn't support resource-level scoping.
    resources = ["*"]
  }

  statement {
    sid       = "RedshiftServerlessCredentials"
    actions   = ["redshift-serverless:GetCredentials"]
    resources = ["arn:${data.aws_partition.current.partition}:redshift-serverless:${var.region}:${local.account_id}:workgroup/*"]
  }

  statement {
    sid = "GlueCatalogRead"
    actions = [
      "glue:GetCatalog", "glue:GetDatabase", "glue:GetTable",
      "glue:GetTables", "glue:GetPartitions", "glue:GetConnection",
      "glue:GetUnfilteredTableMetadata", "glue:GetUnfilteredPartitionMetadata",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${local.account_id}:catalog",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${local.account_id}:catalog/*",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${local.account_id}:database/*",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${local.account_id}:table/*/*",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${local.account_id}:connection/${local.federated_catalog_prefix}*",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${local.account_id}:catalog/${local.federated_catalog_prefix}*",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${local.account_id}:database/${local.federated_catalog_prefix}*/*",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${local.account_id}:table/${local.federated_catalog_prefix}*/*/*",
    ]
  }

  statement {
    sid       = "LakeFormationGetDataAccess"
    actions   = ["lakeformation:GetDataAccess"]
    resources = ["*"]
  }

  statement {
    sid = "AthenaSpillBucket"
    actions = [
      "s3:GetObject", "s3:PutObject", "s3:ListBucket",
      "s3:GetBucketLocation", "s3:AbortMultipartUpload",
      "s3:ListMultipartUploadParts", "s3:DeleteObject",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.athena_spill_bucket_name}",
      "arn:${data.aws_partition.current.partition}:s3:::${var.athena_spill_bucket_name}/*",
    ]
  }

  # ── Athena federation Allow + Deny pair ──────────────────────────
  # See CDK comments — these are the guards against Athena-mediated
  # Lambda invocation escalation into the federation provisioner
  # (which holds LF admin).

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
      variable = "aws:ResourceTag/${var.connector_tag_key}"
      values   = [var.connector_tag_value]
    }
  }

  statement {
    sid       = "DenyAthenaInvokeOfUntaggedFunctions"
    effect    = "Deny"
    actions   = ["lambda:InvokeFunction"]
    resources = ["arn:${data.aws_partition.current.partition}:lambda:*:${local.account_id}:function:*"]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:CalledVia"
      values   = ["athena.amazonaws.com"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:ResourceTag/${var.connector_tag_key}"
      values   = [var.connector_tag_value]
    }
  }

  # ── Federation spill reads ───────────────────────────────────────

  statement {
    sid       = "AthenaFederationSpillRead"
    actions   = ["s3:GetObject"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::*/${var.connector_spill_key_glob}"]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:CalledVia"
      values   = ["athena.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  statement {
    sid       = "AthenaFederationSpillBucketLocation"
    actions   = ["s3:GetBucketLocation"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::*"]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:CalledVia"
      values   = ["athena.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }
  }

  statement {
    sid       = "AthenaFederationSpillList"
    actions   = ["s3:ListBucket"]
    resources = ["arn:${data.aws_partition.current.partition}:s3:::*"]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "aws:CalledVia"
      values   = ["athena.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.region]
    }

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = [var.connector_spill_key_glob]
    }
  }

  statement {
    sid       = "AthenaFederationSpillDecryptViaS3"
    actions   = ["kms:Decrypt"]
    resources = ["arn:${data.aws_partition.current.partition}:kms:${var.region}:*:key/*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${var.region}.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/${var.connector_spill_kms_tag_key}"
      values   = [var.connector_spill_kms_tag_value]
    }
  }

  # ── Secrets Manager: platform secrets (untagged only) ────────────
  # See CDK: JDBC credential secrets are gated by resource-based
  # policies with tag conditions. This identity grant is deliberately
  # scoped to UNTAGGED secrets so it can't shadow the namespace-tag
  # check on credential secrets.
  statement {
    sid     = "ReadPlatformSecrets"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      "arn:${data.aws_partition.current.partition}:secretsmanager:${var.region}:${local.account_id}:secret:${var.resource_prefix}-*",
    ]

    condition {
      test     = "Null"
      variable = "secretsmanager:ResourceTag/${var.namespace_tag_key}"
      values   = ["true"]
    }
  }

  # ── AOSS APIAccessAll (for graphrag lexical-baseline retriever) ──
  statement {
    sid       = "AossApiAccess"
    actions   = ["aoss:APIAccessAll"]
    resources = [var.opensearch_collection_arn]
  }

  # ── Invoke the AOSS search proxy Lambda ──────────────────────────
  statement {
    sid       = "InvokeAossProxy"
    actions   = ["lambda:InvokeFunction"]
    resources = [aws_lambda_function.aoss_proxy.arn]
  }
}

# The full runtime policy exceeds IAM's 6144-char managed policy quota.
# Inline role policies have a 10240-char per-role limit, which fits.
resource "aws_iam_role_policy" "runtime" {
  name   = "${var.name_prefix}-context-manager-runtime-policy"
  role   = aws_iam_role.runtime.name
  policy = data.aws_iam_policy_document.runtime.json
}

# ═════════════════════════════════════════════════════════════════════
#  AOSS data-access policy for the runtime role
# ═════════════════════════════════════════════════════════════════════
# Reads by the graphrag retrievers require both the IAM action above
# AND a data-access policy naming the role as principal.

resource "aws_opensearchserverless_access_policy" "serve_runtime" {
  name        = "${var.name_prefix}-serve-read-only"
  type        = "data"
  description = "Read-only data access for AgentCore runtime task"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "index"
          Resource     = ["index/${var.opensearch_collection_name}/*"]
          Permission   = ["aoss:DescribeIndex", "aoss:ReadDocument"]
        },
        {
          ResourceType = "collection"
          Resource     = ["collection/${var.opensearch_collection_name}"]
          Permission   = ["aoss:DescribeCollectionItems"]
        },
      ]
      Principal = [aws_iam_role.runtime.arn]
    }
  ])
}
