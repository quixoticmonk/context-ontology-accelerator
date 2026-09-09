# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Four API Lambdas: namespace_api, roles_api, platform_roles_api,
# grants_api. All share the same control-plane zip (produced by the
# module's Makefile) and run in the platform VPC.
#
# Every Lambda gets its own execution role — matches CDK's per-function
# role model. The AWSLambdaVPCAccessExecutionRole managed policy grants
# ENI create/describe/delete + CloudWatch Logs; per-Lambda inline
# policies add the specific grants each handler needs.

locals {
  # Reusable env fragment injected into every Lambda (matches CDK's
  # BrandEnvAspect). Callers can layer additional vars on top.
  brand_env = {
    # Populated by the root — passed through as `var.brand_env` in a
    # future refactor. For now the defaults live at root:
    # locals.brand_env = { GRAPH_BASE_URI, EVENT_SOURCE_PREFIX }.
    # The namespace module doesn't currently take brand_env as an
    # input — every Lambda's env below sets nothing brand-related on
    # its own. If runtime handlers require it, add a var here.
  }

  # Deterministic zip content hash — triggers Lambda redeploy when the
  # Makefile rebuilds the zip. `filebase64sha256` is safe as long as
  # the Makefile has run; if the file is missing, plan errors out with
  # a clear message pointing to `make build-lambdas`.
  lambda_zip_hash = filebase64sha256(var.control_plane_zip_path)

  namespace_api_env = merge(
    {
      NAMESPACES_TABLE             = aws_dynamodb_table.namespaces.name
      ROLES_TABLE                  = var.roles_table_name
      RESOURCE_ROLE_MAPPINGS_TABLE = var.resource_role_mappings_table_name
      SOURCES_TABLE                = "${var.name_prefix}-sources"
      METRIC_IMPORT_JOBS_TABLE     = "${var.name_prefix}-metric-import-jobs"
      DATAZONE_DOMAIN_ID           = aws_datazone_domain.this.id
      DATAZONE_PROJECT_PROFILE_ID  = awscc_datazone_project_profile.default.project_profile_id
      ALLOWED_ORIGIN               = var.allowed_origin
      PROJECT_ACCESS_ROLE_ARN_SSM  = "${var.ssm_prefix}/smus/dz-project-access-role-arn"
      ATHENA_RESULTS_BUCKET_SSM    = "${var.ssm_prefix}/query/athena-results-bucket"
      RESOURCE_PREFIX              = "${var.name_prefix}-"
      TAG_PREFIX                   = var.resource_prefix
      DELETION_STATE_MACHINE_ARN   = aws_sfn_state_machine.namespace_deletion.arn
    },
    var.ontology_engine_endpoint != null ? { ONTOLOGY_ENGINE_ENDPOINT = var.ontology_engine_endpoint } : {},
    var.vkg_cluster_arn != null ? { VKG_CLUSTER_ARN = var.vkg_cluster_arn } : {},
  )
}

# ═════════════════════════════════════════════════════════════════════
#  Shared execution-role policy (AWSLambdaVPCAccessExecutionRole)
# ═════════════════════════════════════════════════════════════════════

data "aws_iam_policy" "vpc_access" {
  arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

data "aws_iam_policy_document" "lambda_trust" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# ═════════════════════════════════════════════════════════════════════
#  1. Namespace API Lambda (create + list + delete-trigger)
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "namespace_api" {
  name = "${local.fn_namespace_api}-role"

  # Trust policy: standard Lambda service principal PLUS the deletion
  # pipeline's DeletePlatform role (which assumes this role to call
  # datazone:DeleteProject as the project owner — see cleanup.py's
  # delete_smu_project). No cycle: del_platform role has lambda-only
  # trust, only THIS role's trust references del_platform.
  assume_role_policy = data.aws_iam_policy_document.namespace_api_trust_updated.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "namespace_api_vpc" {
  role       = aws_iam_role.namespace_api.name
  policy_arn = data.aws_iam_policy.vpc_access.arn
}

data "aws_iam_policy_document" "namespace_api_trust_updated" {
  statement {
    sid     = "LambdaService"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }

  statement {
    sid     = "DeletePlatformCrossAssume"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.del_platform.arn]
    }
  }
}

# Namespace API + DDB permissions
data "aws_iam_policy_document" "namespace_api_policy" {
  # Full R/W on the three primary tables
  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [
      aws_dynamodb_table.namespaces.arn,
      "${aws_dynamodb_table.namespaces.arn}/index/*",
      var.roles_table_arn,
      "${var.roles_table_arn}/index/*",
      var.resource_role_mappings_table_arn,
      "${var.resource_role_mappings_table_arn}/index/*",
    ]
  }

  # Read-only preflight queries against sources + metric-import-jobs
  # tables (ByNamespace GSI on sources; primary key on metric-import-jobs)
  statement {
    actions = ["dynamodb:Query"]
    resources = [
      "arn:${data.aws_partition.current.partition}:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.name_prefix}-sources/index/ByNamespace",
      "arn:${data.aws_partition.current.partition}:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.name_prefix}-metric-import-jobs",
    ]
  }

  statement {
    actions   = ["dynamodb:TransactWriteItems"]
    resources = [aws_dynamodb_table.namespaces.arn, var.roles_table_arn, var.resource_role_mappings_table_arn]
  }

  statement {
    actions = [
      "datazone:CreateProject",
      "datazone:CreateProjectMembership",
      "datazone:DeleteProject",
    ]
    # V2 domains require wildcard because the project doesn't exist yet
    # to scope to (matches CDK).
    resources = ["*"]
  }

  statement {
    actions   = ["iam:GetRole"]
    resources = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}*"]
  }

  statement {
    actions = ["ssm:GetParameter"]
    resources = [
      "arn:${data.aws_partition.current.partition}:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_prefix}/smus/*",
      "arn:${data.aws_partition.current.partition}:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_prefix}/query/*",
    ]
  }

  # Athena workgroup creation (deletion moved to deletion pipeline).
  statement {
    actions   = ["athena:CreateWorkGroup", "athena:GetWorkGroup", "athena:TagResource"]
    resources = ["arn:${data.aws_partition.current.partition}:athena:${var.region}:${data.aws_caller_identity.current.account_id}:workgroup/${var.name_prefix}*"]
  }

  # Start the deletion Step Function
  statement {
    actions   = ["states:StartExecution"]
    resources = [aws_sfn_state_machine.namespace_deletion.arn]
  }

  # VKG health resolution (ecs:DescribeServices scoped by ecs:cluster).
  dynamic "statement" {
    for_each = var.vkg_cluster_arn != null ? [1] : []
    content {
      actions   = ["ecs:DescribeServices"]
      resources = ["*"]

      condition {
        test     = "ArnLike"
        variable = "ecs:cluster"
        values   = [var.vkg_cluster_arn]
      }
    }
  }
}

resource "aws_iam_policy" "namespace_api" {
  name   = "${local.fn_namespace_api}-policy"
  policy = data.aws_iam_policy_document.namespace_api_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "namespace_api" {
  role       = aws_iam_role.namespace_api.name
  policy_arn = aws_iam_policy.namespace_api.arn
}

resource "aws_lambda_function" "namespace_api" {
  function_name    = local.fn_namespace_api
  role             = aws_iam_role.namespace_api.arn
  runtime          = "python3.12"
  handler          = "coa_control_plane.namespace.namespace_api_handler.handler"
  filename         = var.control_plane_zip_path
  source_code_hash = local.lambda_zip_hash
  timeout          = 15
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = local.namespace_api_env
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  2. Roles API Lambda (list/get namespace roles)
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "roles_api" {
  name               = "${local.fn_roles_api}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "roles_api_vpc" {
  role       = aws_iam_role.roles_api.name
  policy_arn = data.aws_iam_policy.vpc_access.arn
}

data "aws_iam_policy_document" "roles_api_policy" {
  statement {
    actions   = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan"]
    resources = [var.roles_table_arn, "${var.roles_table_arn}/index/*"]
  }
}

resource "aws_iam_policy" "roles_api" {
  name   = "${local.fn_roles_api}-policy"
  policy = data.aws_iam_policy_document.roles_api_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "roles_api" {
  role       = aws_iam_role.roles_api.name
  policy_arn = aws_iam_policy.roles_api.arn
}

resource "aws_lambda_function" "roles_api" {
  function_name    = local.fn_roles_api
  role             = aws_iam_role.roles_api.arn
  runtime          = "python3.12"
  handler          = "coa_control_plane.roles.namespace_roles_handler.handler"
  filename         = var.control_plane_zip_path
  source_code_hash = local.lambda_zip_hash
  timeout          = 10
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      ROLES_TABLE    = var.roles_table_name
      ALLOWED_ORIGIN = var.allowed_origin
    }
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  3. Platform Roles API Lambda (list platform-scoped roles)
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "platform_roles_api" {
  name               = "${local.fn_platform_roles_api}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "platform_roles_api_vpc" {
  role       = aws_iam_role.platform_roles_api.name
  policy_arn = data.aws_iam_policy.vpc_access.arn
}

resource "aws_iam_policy" "platform_roles_api" {
  name   = "${local.fn_platform_roles_api}-policy"
  policy = data.aws_iam_policy_document.roles_api_policy.json # Same read shape
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "platform_roles_api" {
  role       = aws_iam_role.platform_roles_api.name
  policy_arn = aws_iam_policy.platform_roles_api.arn
}

resource "aws_lambda_function" "platform_roles_api" {
  function_name    = local.fn_platform_roles_api
  role             = aws_iam_role.platform_roles_api.arn
  runtime          = "python3.12"
  handler          = "coa_control_plane.roles.list_platform_roles_handler.handler"
  filename         = var.control_plane_zip_path
  source_code_hash = local.lambda_zip_hash
  timeout          = 5
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      ROLES_TABLE    = var.roles_table_name
      ALLOWED_ORIGIN = var.allowed_origin
    }
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  4. Grants API Lambda (CRUD)
# ═════════════════════════════════════════════════════════════════════

resource "aws_iam_role" "grants_api" {
  name               = "${local.fn_grants_api}-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_trust.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "grants_api_vpc" {
  role       = aws_iam_role.grants_api.name
  policy_arn = data.aws_iam_policy.vpc_access.arn
}

data "aws_iam_policy_document" "grants_api_policy" {
  statement {
    actions   = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan"]
    resources = [var.roles_table_arn, "${var.roles_table_arn}/index/*"]
  }

  statement {
    actions = [
      "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem",
      "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan",
      "dynamodb:BatchWriteItem", "dynamodb:BatchGetItem",
    ]
    resources = [var.resource_role_mappings_table_arn, "${var.resource_role_mappings_table_arn}/index/*"]
  }
}

resource "aws_iam_policy" "grants_api" {
  name   = "${local.fn_grants_api}-policy"
  policy = data.aws_iam_policy_document.grants_api_policy.json
  tags   = local.tags
}

resource "aws_iam_role_policy_attachment" "grants_api" {
  role       = aws_iam_role.grants_api.name
  policy_arn = aws_iam_policy.grants_api.arn
}

resource "aws_lambda_function" "grants_api" {
  function_name    = local.fn_grants_api
  role             = aws_iam_role.grants_api.arn
  runtime          = "python3.12"
  handler          = "coa_control_plane.grants.grants_handler.handler"
  filename         = var.control_plane_zip_path
  source_code_hash = local.lambda_zip_hash
  timeout          = 10
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.lambda_security_group_id]
  }

  environment {
    variables = {
      ROLES_TABLE                  = var.roles_table_name
      RESOURCE_ROLE_MAPPINGS_TABLE = var.resource_role_mappings_table_name
      ALLOWED_ORIGIN               = var.allowed_origin
    }
  }

  tags = local.tags
}

# ═════════════════════════════════════════════════════════════════════
#  Register namespace_api role in DataZone (needed for CreateProject
#  during namespace creation) + grant it root-domain-unit ownership.
# ═════════════════════════════════════════════════════════════════════

resource "aws_datazone_user_profile" "namespace_api" {
  domain_identifier = aws_datazone_domain.this.id
  user_identifier   = aws_iam_role.namespace_api.arn
  user_type         = "IAM_ROLE"

  lifecycle {
    prevent_destroy = false
  }
}

resource "awscc_datazone_owner" "namespace_api_root_domain_unit" {
  domain_identifier = aws_datazone_domain.this.id
  entity_type       = "DOMAIN_UNIT"
  entity_identifier = aws_datazone_domain.this.root_domain_unit_id

  owner = {
    user = {
      user_identifier = aws_iam_role.namespace_api.arn
    }
  }

  depends_on = [aws_datazone_user_profile.namespace_api]
}
