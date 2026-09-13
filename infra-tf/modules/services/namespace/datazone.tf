# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# DataZone (SMUS) domain, project profile, system project, form type,
# asset type, plus the user/project/owner registrations needed for the
# deployer's IAM identity to CreateAssetType successfully.
#
# Split across providers:
#   - aws:   domain, form_type, asset_type, user_profile, policy_grant
#   - awscc: project_profile, project, project_membership, owner
#           (these V2/domain-unit resources have no aws-provider
#            counterpart in v6.63.0)
#
# Ordering / lifecycle:
#   The CDK ancestor marked every DataZone resource RemovalPolicy.RETAIN so
#   CFN never tried to delete them itself — DataZone requires specific
#   pre-delete state (FormType DISABLED, project ownership cascades)
#   that CFN could not satisfy. The TF equivalent is
#   `lifecycle { prevent_destroy = false }` on the domain and its
#   children; teardown is handled by `infra-tf/scripts/nuke-coa-dev.sh`
#   which calls `datazone delete-domain --skip-deletion-check` directly.

# ═════════════════════════════════════════════════════════════════════
#  Domain (V2, IAM-based)
# ═════════════════════════════════════════════════════════════════════

resource "aws_datazone_domain" "this" {
  name                  = local.smus_domain_name
  domain_version        = "V2"
  domain_execution_role = aws_iam_role.smus_exec.arn
  service_role          = aws_iam_role.smus_exec.arn
  description           = "SMUS domain for namespace isolation and metadata management"
  skip_deletion_check   = true

  tags = local.tags

  # See file header — teardown goes through destroy.sh, not tf destroy.
  lifecycle {
    prevent_destroy = false
  }
}

# ═════════════════════════════════════════════════════════════════════
#  Deployer identity registration (needed to CreateAssetType)
# ═════════════════════════════════════════════════════════════════════
# CreateAssetType requires the caller to be:
#   (1) a user profile in the domain
#   (2) a project member on the owning project (system project) with
#       PROJECT_OWNER designation
#   (3) an owner of the root domain unit (for the CREATE_ASSET_TYPE
#       policy grant's project-filter to include them)
#
# In the CDK, the CustomResource Lambda plays this role. In TF, the aws
# provider makes API calls using the deployer's IAM credentials, so we
# register the DEPLOYER role instead.

data "aws_arn" "deployer" {
  arn = data.aws_caller_identity.current.arn
}

locals {
  # Terraform is often run under an assumed role. The user_identifier
  # DataZone expects is the ROLE ARN, not the session ARN — strip the
  # session suffix when needed. STS assumed-role ARNs look like:
  #   arn:aws:sts::<acct>:assumed-role/<role-name>/<session-name>
  # Convert to:
  #   arn:aws:iam::<acct>:role/<role-name>
  deployer_arn_normalized = (
    can(regex("^arn:[^:]+:sts::[0-9]+:assumed-role/", data.aws_caller_identity.current.arn))
    ? "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${split("/", data.aws_caller_identity.current.arn)[1]}"
    : data.aws_caller_identity.current.arn
  )
}

# NOTE: no `aws_datazone_user_profile.deployer` resource.
#
# DataZone auto-registers a user profile for the calling role the moment
# ANY DataZone API call is made under that role — including CreateDomain.
# By the time TF's own resource block would execute, DataZone already has
# a profile with the same identifier and returns 409 on CreateUserProfile.
# The AWS provider's destroy for this resource is also a no-op (deactivate,
# not delete), so import + apply enters a permanent replace loop.
#
# The profile *does* exist by the time any downstream DataZone action runs.
# Downstream resources that used to `depends_on` this resource now depend
# on `aws_datazone_domain.this` directly — the domain create is what
# triggers auto-registration.

resource "aws_datazone_user_profile" "dz_project_access" {
  domain_identifier = aws_datazone_domain.this.id
  user_identifier   = aws_iam_role.dz_project_access.arn
  user_type         = "IAM_ROLE"

  lifecycle {
    prevent_destroy = false
  }
}

# NOTE: no explicit `awscc_datazone_owner.deployer_root_domain_unit`.
#
# DataZone auto-adds the caller's group profile as an OWNER of the root
# domain unit when the domain is created. An explicit AddEntityOwner call
# for that same principal returns 400 "Group profile already exists for
# the given User profile" regardless of whether you pass the role ARN or
# the profile UUID.
#
# Downstream resources (policy grants, asset types) that used to
# depends_on this owner now depend on `aws_datazone_domain.this` — the
# implicit ownership is guaranteed by the time the domain reports
# AVAILABLE.

# ═════════════════════════════════════════════════════════════════════
#  Project profile + system project
# ═════════════════════════════════════════════════════════════════════

resource "awscc_datazone_project_profile" "default" {
  domain_identifier = aws_datazone_domain.this.id
  name              = local.project_profile_name
  description       = "Default metadata-only project profile"
  status            = "ENABLED"

  # DataZone auto-registers a user profile for the calling role on any
  # domain action (project profile create, project create, membership...).
  # Explicit aws_datazone_user_profile.deployer must run first, else it
  # races and 409s on the auto-created profile.
  depends_on = [aws_datazone_domain.this]

  lifecycle {
    prevent_destroy = false
  }
}

resource "awscc_datazone_project" "system" {
  domain_identifier  = aws_datazone_domain.this.id
  name               = local.system_project_name
  description        = "System project owning shared form and asset types"
  project_profile_id = awscc_datazone_project_profile.default.project_profile_id

  # Same reason as awscc_datazone_project_profile.default — force
  # explicit deployer profile creation to win the race.
  depends_on = [aws_datazone_domain.this]

  lifecycle {
    prevent_destroy = false
  }
}

# awscc_datazone_project.system.id is the composite `domain|project` string
# ("dzd-...|<project>"). The AWS provider's downstream resources (form types,
# asset types) validate the bare project ID against `^[a-zA-Z0-9_-]{1,36}$`,
# so strip the domain prefix once and reuse.
locals {
  system_project_id = split("|", awscc_datazone_project.system.id)[1]
}

# NOTE: no explicit `awscc_datazone_project_membership.deployer_system_owner`.
#
# DataZone auto-adds the calling role (via its group profile) as PROJECT_OWNER
# of any project the caller creates. Adding an explicit membership fails
# with "Group profile already exists for the given User profile".

# ═════════════════════════════════════════════════════════════════════
#  Policy grants (CREATE_FORM_TYPE + CREATE_ASSET_TYPE)
# ═════════════════════════════════════════════════════════════════════
# Grant projects designated OWNER on the root domain unit the ability
# to create form types and asset types. The system project inherits
# these grants via its ownership of the root domain unit (established
# above via the deployer_root_domain_unit owner).

resource "aws_datazone_policy_grant" "create_form_type" {
  domain_identifier = aws_datazone_domain.this.id
  entity_type       = "DOMAIN_UNIT"
  entity_identifier = aws_datazone_domain.this.root_domain_unit_id
  policy_type       = "CREATE_FORM_TYPE"

  detail {
    create_form_type {
      include_child_domain_units = true
    }
  }

  principal {
    project {
      project_designation = "OWNER"

      domain_unit_filter {
        domain_unit                = aws_datazone_domain.this.root_domain_unit_id
        include_child_domain_units = true
      }
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_datazone_policy_grant" "create_asset_type" {
  domain_identifier = aws_datazone_domain.this.id
  entity_type       = "DOMAIN_UNIT"
  entity_identifier = aws_datazone_domain.this.root_domain_unit_id
  policy_type       = "CREATE_ASSET_TYPE"

  detail {
    create_asset_type {
      include_child_domain_units = true
    }
  }

  principal {
    project {
      project_designation = "OWNER"

      domain_unit_filter {
        domain_unit                = aws_datazone_domain.this.root_domain_unit_id
        include_child_domain_units = true
      }
    }
  }

  lifecycle {
    prevent_destroy = false
  }
}

# ═════════════════════════════════════════════════════════════════════
#  Form Type + Asset Type
# ═════════════════════════════════════════════════════════════════════
# The Smithy model matches the CDK CoaTableMetadata form exactly. The
# native `aws_datazone_form_type` supports both `model.smithy` and
# `model.json_schema` (we use smithy).

resource "aws_datazone_form_type" "coa_table_metadata" {
  domain_identifier         = aws_datazone_domain.this.id
  name                      = "CoaTableMetadata"
  owning_project_identifier = local.system_project_id
  status                    = "ENABLED"
  description               = "Enriched table metadata: technical metadata, business metadata, PKs, FKs, columns"

  model {
    smithy = join("\n", [
      "structure CoaTableMetadata {",
      "    @amazon.datazone#searchable",
      "    tableName: smithy.api#String",
      "    @amazon.datazone#searchable",
      "    databaseName: smithy.api#String",
      "    @amazon.datazone#searchable",
      "    dataSourceId: smithy.api#String",
      "    @amazon.datazone#searchable",
      "    namespaceId: smithy.api#String",
      "    databaseDescription: smithy.api#String",
      "    @amazon.datazone#searchable",
      "    description: smithy.api#String",
      "    columnCount: smithy.api#Integer",
      "    partitionKeys: smithy.api#String",
      "    format: smithy.api#String",
      "    location: smithy.api#String",
      "    @amazon.datazone#searchable",
      "    synonyms: smithy.api#String",
      "    @amazon.datazone#searchable",
      "    glossaryTerms: smithy.api#String",
      "    tags: smithy.api#String",
      "    enrichmentSource: smithy.api#String",
      "    reviewStatus: smithy.api#String",
      "    primaryKeyColumns: smithy.api#String",
      "    primaryKeySource: smithy.api#String",
      "    primaryKeyConfidence: smithy.api#Float",
      "    foreignKeys: smithy.api#String",
      "    columns: smithy.api#String",
      "}",
    ])
  }

  depends_on = [aws_datazone_policy_grant.create_form_type]

  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_datazone_asset_type" "coa_relational_table" {
  domain_identifier         = aws_datazone_domain.this.id
  name                      = "CoaRelationalTable"
  owning_project_identifier = local.system_project_id
  description               = "Relational table asset (Glue or JDBC source)"

  forms_input {
    map_block_key   = "CoaTableMetadata"
    type_identifier = aws_datazone_form_type.coa_table_metadata.name
    type_revision   = aws_datazone_form_type.coa_table_metadata.revision
    required        = false
  }

  depends_on = [
    aws_datazone_policy_grant.create_asset_type,
  ]

  lifecycle {
    prevent_destroy = false
  }
}
