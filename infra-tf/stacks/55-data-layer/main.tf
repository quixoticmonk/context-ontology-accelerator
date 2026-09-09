# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Stack 55 — Data-layer Lambda. Split out of 30-services to break the
# circular dependency: data-layer needs the serve AgentCore Runtime ARN
# from stack 50-agentcore, and stack 60-api-edge needs data-layer's Lambda ARN.
# Runs after 50-agentcore, before 60-api-edge.

module "data_layer" {
  source = "../../modules/services/data-layer"

  allowed_origin             = local.allowed_origin
  data_layer_zip_path        = "${path.root}/../../artifacts/lambdas/data-layer.zip"
  lambda_security_group_id   = local.lambda_security_group_id
  metric_api_fn_arn          = local.metric_api_fn_arn
  name_prefix                = local.name_prefix
  namespaces_table_name      = local.namespaces_table_name
  ontology_engine_api_fn_arn = local.ontology_engine_api_fn_arn
  private_subnet_ids         = local.private_subnet_ids
  region                     = var.region
  serve_runtime_arn          = local.serve_runtime_arn
  ssm_prefix                 = local.ssm_prefix
  vpc_id                     = local.vpc_id
}
