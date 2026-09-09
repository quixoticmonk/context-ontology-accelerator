# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  # ── Physical names (match CDK prefixed() outputs) ─────────────────
  table_name     = "${var.name_prefix}-ontology-engine"
  cluster_name   = "${var.name_prefix}-ontology-cluster"
  service_name   = "${var.name_prefix}-ontology-engine"
  task_family    = "${var.name_prefix}-ontology-engine"
  container_name = "${var.name_prefix}-ontology-engine"
  log_group      = "/ecs/${var.name_prefix}-ontology-engine"
  oss_policy     = "${var.name_prefix}-ontology-oss"
  api_fn_name    = "${var.name_prefix}-ontology-api-proxy"

  # Cross-service Lambda name — sources-api lives in the sources module but
  # is constructed by convention (matches CDK this.prefixed("sources-api")).
  sources_api_fn_name = "${var.name_prefix}-sources-api"

  # ── Cloud Map DNS endpoint ─────────────────────────────────────────
  # http://ontology-engine.<namespace>:<port> — resolvable VPC-wide (real
  # Route 53 A records, not Service Connect). Lambda needs the FQDN.
  endpoint = "http://ontology-engine.${var.service_namespace_name}:${var.container_port}"

  # ── Container image URI ────────────────────────────────────────────
  # When the image tag file exists, pin to that digest/tag; otherwise fall
  # back to :latest on the module-created ECR repo (first-deploy path).
  image_uri = var.image_tag_file != null ? trimspace(file(var.image_tag_file)) : "${var.ecr_repository_url}:latest"

  # ── Lambda zip content hash ────────────────────────────────────────
  # try() so plan does not hard-fail before the Makefile has run; a missing
  # zip surfaces at apply as a clear "file not found" on the filename arg.
  api_zip_hash = try(filebase64sha256(var.ontology_api_zip_path), null)

  # ── Bedrock inference-profile ARNs (gotcha #1) ─────────────────────
  # Cross-region inference profiles (us.* prefix) have NO region path segment
  # in the profile ARN. Grant the profile itself AND the underlying
  # foundation-model (prefix stripped) so the first-hop InvokeModel resolves.
  bedrock_models = toset([
    var.bedrock_embed_model_id,
    var.bedrock_induction_llm_model_id,
    var.bedrock_chat_model_id,
  ])

  inference_profile_arns = [
    for m in local.bedrock_models :
    "arn:aws:bedrock:${var.region}::inference-profile/${m}"
  ]

  foundation_model_arns = [
    for m in local.bedrock_models :
    "arn:aws:bedrock:*::foundation-model/${trimprefix(m, "us.")}"
  ]

  # ── Common tags ────────────────────────────────────────────────────
  tags = {
    Component = var.component
  }
}
