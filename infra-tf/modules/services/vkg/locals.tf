# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

locals {
  # ── Physical names (match CDK prefixed() outputs) ─────────────────
  cluster_name    = "${var.name_prefix}-vkg-cluster"
  task_family     = "${var.name_prefix}-vkg-service"
  container_name  = "${var.name_prefix}-ontop"
  reload_fn_name  = "${var.name_prefix}-vkg-reload"
  log_group_name  = "/ecs/${var.name_prefix}-vkg-service"
  reload_rule     = "${var.name_prefix}-ontology-reload"
  reload_sweep    = "${var.name_prefix}-vkg-reload-sweep"
  metric_alarm    = "${var.name_prefix}-vkg-reload-failed"
  vkg_image_param = "${var.ssm_prefix}/vkg/container-image"

  # ── Container image URI ────────────────────────────────────────────
  # Resolved from the image tag file written by the image Makefile; falls
  # back to <ecr_repo>:latest when the file is not provided (matches the
  # CDK's fromEcrRepository default tag behavior).
  image_uri = var.image_tag_file != null ? trimspace(file(var.image_tag_file)) : "${var.ecr_repository_url}:latest"

  # ── EventBridge source ─────────────────────────────────────────────
  # The reload rule matches the deployment-scoped source the ontology
  # publisher emits: <event_source_prefix>.ontology. The CDK derives this
  # from the eventSourcePrefix context; here it is an explicit input.
  event_source = "${var.event_source_prefix}.ontology"

  # ── Reserved concurrency (CDK undefined -> omit) ───────────────────
  reserved_concurrency = var.lambda_reserved_concurrency > 0 ? var.lambda_reserved_concurrency : null

  # ── Deterministic zip content hash (triggers Lambda redeploy) ──────
  reload_zip_hash = try(filebase64sha256(var.vkg_reload_zip_path), null)

  # ── VKG endpoint pattern (per-namespace services resolve as
  #    vkg-{ns}.<namespace>:port) ──────────────────────────────────────
  vkg_endpoint = "http://vkg.${var.service_namespace_name}:${var.container_port}"

  # ── Ontop JVM args ─────────────────────────────────────────────────
  # The Ontop launcher reads ONTOP_JAVA_ARGS (NOT JAVA_OPTS — see
  # packages/vkg/entrypoint.sh; #149 cause C). When not overridden,
  # derive the heap from memory_limit_mib so bumping memory alone scales
  # the heap in step, leaving headroom for the JVM, H2, and the Python
  # facade. Floors of 512m/256m match the CDK derivation.
  ontop_java_args = coalesce(
    var.ontop_java_args,
    "-Xmx${max(512, floor(var.memory_limit_mib * 3 / 4))}m -Xms${max(256, floor(var.memory_limit_mib / 4))}m",
  )

  # ── Common tags ────────────────────────────────────────────────────
  tags = {
    Component = var.component
  }
}
