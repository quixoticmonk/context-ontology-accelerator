# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  name_prefix = "${var.resource_prefix}-${var.env}"
  ssm_prefix  = "/${var.resource_prefix}"

  common_tags = {
    Environment = var.env
    ManagedBy   = "Terraform"
    Project     = var.project_tag
  }

  # ECR repositories owned by this stack. Each key becomes both an SSM
  # parameter suffix and the aws_ecr_repository resource key.
  #
  # Physical names match what the service modules used to create so
  # image Makefiles that reference `<name_prefix>-<component>` continue
  # to work verbatim.
  repositories = {
    ontology_engine       = "${local.name_prefix}-ontology-engine"
    vkg                   = "${local.name_prefix}-vkg"
    mcp_server            = "${local.name_prefix}-mcp-server"
    context_manager       = "${local.name_prefix}-context-manager"
    sources_db_enrichment = "${local.name_prefix}-sources-db-enrichment"
    sources_preprocessing = "${local.name_prefix}-sources-doc-preprocessing"
    sources_kg_build      = "${local.name_prefix}-sources-doc-kg-build"
  }

  # Non-prod environments get force_delete so `terraform destroy` can
  # tear down repos even if they still contain images.
  force_delete = var.env != "prod"
}
