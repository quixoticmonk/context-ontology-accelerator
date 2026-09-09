# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# API proxy Lambda code bundle for the ontology module.
#
# Mirrors the CDK bundlePython() invocation for ApiProxyFn, which merges
# two source directories into one asset root and installs the handler's
# transitive deps explicitly (this Lambda has no requirements.txt of its
# own):
#
#   - packages/ontology-engine/src  (Paths.ontologyEngineSrc) → the
#     coa_ontology package incl. api_proxy_handler
#   - libs/common/src               (Paths.commonLib)         → coa_common
#     (resolve_region and shared config/logging)
#
# pip deps match the CDK pipDeps list for this asset.
#
# Output: infra-tf/artifacts/lambdas/ontology-api.zip
# locals.tf's api_zip_hash = filebase64sha256() over this zip triggers
# Lambda redeploys when the bundle changes.

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# ── Paths (all resolved relative to this Makefile) ──────────────────
# Repo root is 6 dirs up: modules/services/ontology/lambdas/ontology-api/ → root
REPO_ROOT   := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../../../..)
ARTIFACTS   := $(REPO_ROOT)/infra-tf/artifacts/lambdas
OUT_DIR     := $(ARTIFACTS)/ontology-api
ZIP         := $(ARTIFACTS)/ontology-api.zip

# Source directories to merge into the asset root (order matches CDK).
SRC_DIRS := \
  $(REPO_ROOT)/packages/ontology-engine/src \
  $(REPO_ROOT)/libs/common/src

# pip deps — matches CDK bundlePython pipDeps for ApiProxyFn.
PIP_DEPS := \
  "cedarpy>=4.8.0" \
  "pydantic>=2.0" \
  "pydantic-settings>=2.0" \
  "structlog>=24.0" \
  "cryptography>=43.0" \
  "PyJWT>=2.9.0" \
  "requests>=2.32.0"

.PHONY: build clean help
.DEFAULT_GOAL := build

help: ## Show help
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: $(ZIP) ## Build ontology-api.zip

$(ZIP): $(shell find $(SRC_DIRS) -type f 2>/dev/null)
	@echo "==> Building ontology-api Lambda zip"
	@rm -rf $(OUT_DIR)
	@mkdir -p $(OUT_DIR)
	@# Merge every src dir's contents into the zip root. `cp -a` preserves
	@# permissions/timestamps; matches the CDK bundlePython merge behavior.
	@for d in $(SRC_DIRS); do \
	  if [ ! -d "$$d" ]; then \
	    echo "  MISSING source dir: $$d — skipping"; \
	  else \
	    echo "  merging $$d"; \
	    cp -a "$$d"/. $(OUT_DIR)/; \
	  fi; \
	done
	@# Install pip deps into the same tree. uv + wheels-only so nothing
	@# native-compiles against the host toolchain (see the namespace
	@# module's Makefile for the full rationale).
	@echo "==> uv pip install (explicit deps)"
	@uv pip install \
	  --target $(OUT_DIR) \
	  --python-platform x86_64-manylinux2014 \
	  --python-version 3.12 \
	  --only-binary :all: --no-cache -q \
	  $(PIP_DEPS)
	@# Strip .pyc / __pycache__ so the zip hash stays stable across rebuilds.
	@find $(OUT_DIR) -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
	@find $(OUT_DIR) -name '*.pyc' -delete 2>/dev/null || true
	@# Deterministic zip: sorted entries + fixed mtime → same content = same hash.
	@echo "==> Zipping to $(ZIP)"
	@rm -f $(ZIP)
	@cd $(OUT_DIR) && find . -exec touch -t 197001010000 {} + && \
	  find . -type f | sort | zip -X -q -@ $(ZIP)
	@echo "==> Built $(ZIP) ($$(du -sh $(ZIP) | cut -f1))"

clean: ## Remove the staging dir and zip
	rm -rf $(OUT_DIR) $(ZIP)
