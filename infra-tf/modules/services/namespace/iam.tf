# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# IAM roles + policies for the namespace stack.
#
# Three top-level roles:
#   1. smus_exec         — SMUS domain execution + service role, trusted
#                          by 10 SMUS service principals
#   2. dz_project_access — Assumed by service Lambdas for DataZone
#                          project operations (registered as PROJECT_OWNER
#                          on every namespace's project at create time)
#   3. login             — Admin console federation into SMUS
#
# Lambda execution roles are defined alongside their Lambdas
# (api_lambdas.tf, deletion_pipeline.tf).

# ═════════════════════════════════════════════════════════════════════
#  1. SMUS execution role
# ═════════════════════════════════════════════════════════════════════

# Assume-role policy: two statements matching the CDK layout —
#   (a) plain sts:AssumeRole from datazone.amazonaws.com (from assumedBy)
#   (b) sts:AssumeRole + TagSession + SetContext + SetSourceIdentity
#       from all 10 SMUS service principals, scoped by SourceAccount.
data "aws_iam_policy_document" "smus_exec_trust" {
  statement {
    sid     = "DataZoneAssumeRole"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["datazone.amazonaws.com"]
    }
  }

  statement {
    sid = "SmusServicePrincipals"

    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
      "sts:SetContext",
      "sts:SetSourceIdentity",
    ]

    principals {
      type        = "Service"
      identifiers = local.smus_principals
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "smus_exec" {
  name               = local.smus_exec_role_name
  description        = "SMUS domain execution + service role"
  assume_role_policy = data.aws_iam_policy_document.smus_exec_trust.json

  tags = local.tags
}

# Scoped SMUS execution policy — narrower than the AWS-managed
# `SageMakerStudioAdminIAMPermissiveExecutionPolicy`. Only the
# permissions SMUS actually calls, and every ARN is scoped to this
# account + region + prefix where possible.
data "aws_iam_policy_document" "smus_exec" {
  statement {
    sid = "DataZoneDomain"
    actions = [
      "datazone:CreateDomain",
      "datazone:GetDomain",
      "datazone:UpdateDomain",
      "datazone:DeleteDomain",
      "datazone:ListDomains",
      "datazone:CreateProject",
      "datazone:GetProject",
      "datazone:UpdateProject",
      "datazone:DeleteProject",
      "datazone:CreateEnvironment",
      "datazone:GetEnvironment",
      "datazone:UpdateEnvironment",
      "datazone:DeleteEnvironment",
    ]
    resources = ["*"]
  }

  statement {
    sid = "SageMaker"
    actions = [
      "sagemaker:CreateDomain",
      "sagemaker:DescribeDomain",
      "sagemaker:UpdateDomain",
      "sagemaker:DeleteDomain",
      "sagemaker:CreateUserProfile",
      "sagemaker:DescribeUserProfile",
      "sagemaker:UpdateUserProfile",
      "sagemaker:DeleteUserProfile",
      "sagemaker:CreateSpace",
      "sagemaker:DescribeSpace",
      "sagemaker:UpdateSpace",
      "sagemaker:DeleteSpace",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:sagemaker:${var.region}:${data.aws_caller_identity.current.account_id}:domain/*",
      "arn:${data.aws_partition.current.partition}:sagemaker:${var.region}:${data.aws_caller_identity.current.account_id}:user-profile/*",
      "arn:${data.aws_partition.current.partition}:sagemaker:${var.region}:${data.aws_caller_identity.current.account_id}:space/*",
    ]
  }

  statement {
    sid = "Glue"
    actions = [
      "glue:CreateDatabase",
      "glue:GetDatabase",
      "glue:UpdateDatabase",
      "glue:DeleteDatabase",
      "glue:CreateTable",
      "glue:GetTable",
      "glue:UpdateTable",
      "glue:DeleteTable",
      "glue:GetTables",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:database/*",
      "arn:${data.aws_partition.current.partition}:glue:${var.region}:${data.aws_caller_identity.current.account_id}:table/*",
    ]
  }

  statement {
    sid = "LakeFormation"
    actions = [
      "lakeformation:GrantPermissions",
      "lakeformation:RevokePermissions",
      "lakeformation:GetDataAccess",
      "lakeformation:ListPermissions",
    ]
    resources = ["*"]
  }

  statement {
    sid = "Athena"
    actions = [
      "athena:StartQueryExecution",
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:StopQueryExecution",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:athena:${var.region}:${data.aws_caller_identity.current.account_id}:workgroup/*"]
  }

  statement {
    sid = "Redshift"
    actions = [
      "redshift:DescribeClusters",
      "redshift:GetClusterCredentials",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:redshift:${var.region}:${data.aws_caller_identity.current.account_id}:cluster:*"]
  }

  # S3 access scoped to this deployment's resources only (prefix match).
  statement {
    sid = "S3Prefixed"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.name_prefix}*",
      "arn:${data.aws_partition.current.partition}:s3:::${var.name_prefix}*/*",
    ]
  }

  # IAM operations scoped to roles created by this stack only.
  statement {
    sid = "IAMPrefixed"
    actions = [
      "iam:GetRole",
      "iam:PassRole",
      "iam:ListRolePolicies",
      "iam:GetRolePolicy",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}*"]
  }

  statement {
    sid = "Scheduler"
    actions = [
      "scheduler:CreateSchedule",
      "scheduler:GetSchedule",
      "scheduler:UpdateSchedule",
      "scheduler:DeleteSchedule",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:scheduler:${var.region}:${data.aws_caller_identity.current.account_id}:schedule/*"]
  }

  statement {
    sid = "Bedrock"
    actions = [
      "bedrock:CreateAgent",
      "bedrock:GetAgent",
      "bedrock:UpdateAgent",
      "bedrock:DeleteAgent",
      "bedrock:InvokeAgent",
      "bedrock:CreateKnowledgeBase",
      "bedrock:GetKnowledgeBase",
      "bedrock:UpdateKnowledgeBase",
      "bedrock:DeleteKnowledgeBase",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:bedrock:${var.region}:${data.aws_caller_identity.current.account_id}:agent/*",
      "arn:${data.aws_partition.current.partition}:bedrock:${var.region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*",
    ]
  }

  statement {
    sid = "EMRServerless"
    actions = [
      "emr-serverless:CreateApplication",
      "emr-serverless:GetApplication",
      "emr-serverless:UpdateApplication",
      "emr-serverless:DeleteApplication",
      "emr-serverless:StartJobRun",
      "emr-serverless:GetJobRun",
      "emr-serverless:CancelJobRun",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:emr-serverless:${var.region}:${data.aws_caller_identity.current.account_id}:/applications/*"]
  }

  statement {
    sid = "MWAA"
    actions = [
      "airflow:GetEnvironment",
      "airflow:CreateEnvironment",
      "airflow:UpdateEnvironment",
      "airflow:DeleteEnvironment",
    ]
    resources = ["arn:${data.aws_partition.current.partition}:airflow:${var.region}:${data.aws_caller_identity.current.account_id}:environment/*"]
  }
}

resource "aws_iam_policy" "smus_exec" {
  name        = "${var.name_prefix}-smus-exec-policy"
  description = "Scoped permissions for SMUS domain execution role"
  policy      = data.aws_iam_policy_document.smus_exec.json
  tags        = local.tags
}

resource "aws_iam_role_policy_attachment" "smus_exec" {
  role       = aws_iam_role.smus_exec.name
  policy_arn = aws_iam_policy.smus_exec.arn
}

# ═════════════════════════════════════════════════════════════════════
#  2. Shared DataZone project access role
# ═════════════════════════════════════════════════════════════════════
# Trusted by account root — service Lambdas assume it for DataZone
# project ops. Registered as PROJECT_OWNER on every namespace's
# DataZone project at create time (see service.py). The deletion
# pipeline's DeletePlatform step assumes it for DeleteProject.

data "aws_iam_policy_document" "dz_project_access_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "dz_project_access" {
  name               = local.dz_project_access_name
  description        = "Shared role for DataZone project access - assumed by service Lambdas"
  assume_role_policy = data.aws_iam_policy_document.dz_project_access_trust.json

  tags = local.tags
}

data "aws_iam_policy_document" "dz_project_access_datazone" {
  statement {
    actions = [
      "datazone:CreateAsset",
      "datazone:CreateAssetRevision",
      "datazone:CreateFormType",
      "datazone:DeleteAsset",
      "datazone:DeleteProject",
      "datazone:GetAsset",
      "datazone:GetFormType",
      "datazone:GetProject",
      "datazone:ListAssets",
      "datazone:Search",
      "datazone:SearchListings",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:datazone:${var.region}:${data.aws_caller_identity.current.account_id}:domain/${aws_datazone_domain.this.id}",
      "arn:${data.aws_partition.current.partition}:datazone:${var.region}:${data.aws_caller_identity.current.account_id}:domain/${aws_datazone_domain.this.id}/*",
    ]
  }
}

resource "aws_iam_policy" "dz_project_access_datazone" {
  name   = "${var.name_prefix}-dz-project-access-policy"
  policy = data.aws_iam_policy_document.dz_project_access_datazone.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "dz_project_access_datazone" {
  role       = aws_iam_role.dz_project_access.name
  policy_arn = aws_iam_policy.dz_project_access_datazone.arn
}

# ═════════════════════════════════════════════════════════════════════
#  3. SMUS admin login role
# ═════════════════════════════════════════════════════════════════════
# Assumed via console to reach the SMUS UI. Trusted by the specific
# admin ARNs (from context; default: <account>:role/Admin). Optional
# MFA deny statement matches CDK smus_require_mfa.

data "aws_iam_policy_document" "login_trust" {
  statement {
    sid     = "AllowAdminAssume"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = local.admin_principal_arns
    }
  }

  # Optional MFA deny statement (BoolIfExists so principals without an
  # MFA attribute — such as service-principal assumption — are not
  # blocked).
  dynamic "statement" {
    for_each = var.smus_require_mfa ? [1] : []

    content {
      sid     = "DenyAssumeWithoutMFA"
      effect  = "Deny"
      actions = ["sts:AssumeRole"]

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }

      condition {
        test     = "BoolIfExists"
        variable = "aws:MultiFactorAuthPresent"
        values   = ["false"]
      }
    }
  }
}

data "aws_iam_policy_document" "login_pass_role" {
  statement {
    sid       = "IAMPassRoleStatement"
    actions   = ["iam:PassRole"]
    resources = [aws_iam_role.smus_exec.arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["datazone.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "login_pass_role" {
  name   = "${var.name_prefix}-smus-login-passrole"
  policy = data.aws_iam_policy_document.login_pass_role.json
  tags   = local.tags
}

resource "aws_iam_role" "login" {
  name               = local.login_role_name
  description        = "SMUS admin console federation role"
  assume_role_policy = data.aws_iam_policy_document.login_trust.json

  tags = local.tags
}

# AWS-managed policy: SageMakerStudioAdminIAMConsolePolicy.
resource "aws_iam_role_policy_attachment" "login_managed" {
  role       = aws_iam_role.login.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/SageMakerStudioAdminIAMConsolePolicy"
}

resource "aws_iam_role_policy_attachment" "login_pass_role" {
  role       = aws_iam_role.login.name
  policy_arn = aws_iam_policy.login_pass_role.arn
}
