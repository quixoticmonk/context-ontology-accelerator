# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  # ── Physical names (match CDK prefixed() outputs) ─────────────────
  ecr_repo_name = "${var.name_prefix}-mcp-server"

  # AgentCore rejects hyphens in runtime names, so the CDK does
  # .replace(/-/g, "_"). Mirror that transform here.
  runtime_name = replace("${var.name_prefix}-mcp-server", "-", "_")

  # ── Container image URI ────────────────────────────────────────────
  # When the tag file exists, pin to the pushed digest/tag; otherwise fall
  # back to :latest on the module-created ECR repo (first-deploy path).
  image_uri = var.image_tag_file != null ? trimspace(file(var.image_tag_file)) : "${var.ecr_repository_url}:latest"

  # ── AgentCore subnet placement ─────────────────────────────────────
  # Defensive filter: when agentcore_az_names is set, keep only subnets in
  # a supported AZ. Requires a subnet->AZ lookup, so build a map from the
  # data source. When null, use all private_subnet_ids unfiltered.
  runtime_subnet_ids = (
    var.agentcore_az_names != null
    ? [for id, s in data.aws_subnet.private : id if contains(var.agentcore_az_names, s.availability_zone)]
    : var.private_subnet_ids
  )

  # ── Runtime environment variables ──────────────────────────────────
  # brand_env (GRAPH_BASE_URI + EVENT_SOURCE_PREFIX) merged first so the
  # MCP-specific vars below win on any key collision.
  environment_variables = merge(
    var.brand_env,
    {
      ENVIRONMENT               = var.env
      SSM_PREFIX                = var.ssm_prefix
      LOG_LEVEL                 = "INFO"
      AWS_REGION                = var.region
      ROLES_TABLE_NAME          = var.roles_table_name
      RRM_TABLE_NAME            = var.resource_role_mappings_table_name
      GROUP_CLAIM_NAME          = var.group_claim_name
      CM_RUNTIME_ARN            = var.cm_runtime_arn
      METRIC_SERVICE_LAMBDA_ARN = var.metric_service_lambda_arn
      ONTOLOGY_PROXY_LAMBDA_ARN = var.ontology_proxy_lambda_arn
      SCL_MCP_MODE              = "true"
      JWT_ISSUER_URL            = var.issuer_url
      JWT_CLIENT_ID             = var.mcp_client_id
    },
  )

  # ── Common tags ────────────────────────────────────────────────────
  tags = {
    Component = var.component
  }
}
