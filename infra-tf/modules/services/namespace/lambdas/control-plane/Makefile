# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Shared Lambda code bundle for the namespace module.
#
# Every Lambda in this module (4 API handlers + 6 deletion-pipeline
# handlers) runs from the same zip; they differ only in `handler` and
# `environment`. This mirrors the CDK bundlePython() invocation that
# combines three source directories into one asset:
#
#   - packages/control-plane/src   → the API + deletion handlers
#   - libs/common/src              → shared config + logging
#   - smithy-generated/            → generated Python server models
#
# Output: infra-tf/artifacts/lambdas/control-plane.zip
#
# Rebuilt via `make build-lambdas` from the top-level Makefile. The
# resulting zip's content hash triggers Lambda redeploys via
# filebase64sha256() in api_lambdas.tf / deletion_pipeline.tf.

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# ── Paths (all resolved relative to this Makefile) ──────────────────
# Repo root is 6 dirs up: modules/services/namespace/lambdas/control-plane/ → root
REPO_ROOT   := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../../../..)
ARTIFACTS   := $(REPO_ROOT)/infra-tf/artifacts/lambdas
OUT_DIR     := $(ARTIFACTS)/control-plane
ZIP         := $(ARTIFACTS)/control-plane.zip

# Source directories to merge into the asset root.
SRC_DIRS := \
  $(REPO_ROOT)/packages/control-plane/src \
  $(REPO_ROOT)/libs/common/src \
  $(REPO_ROOT)/smithy-generated/control-plane-python-server

# pip requirements — matches CDK's requirementsFile: packages/control-plane/requirements.txt
REQS := $(REPO_ROOT)/packages/control-plane/requirements.txt

.PHONY: build clean help
.DEFAULT_GOAL := build

help: ## Show help
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: $(ZIP) ## Build control-plane.zip

$(ZIP): $(REQS) $(shell find $(SRC_DIRS) -type f 2>/dev/null)
	@echo "==> Building control-plane Lambda zip"
	@rm -rf $(OUT_DIR)
	@mkdir -p $(OUT_DIR)
	@# Merge every src dir's contents into the zip root. `cp -a` preserves
	@# permissions/timestamps; conflicting names would silently overlay,
	@# which is intentional — the CDK bundlePython does exactly this.
	@for d in $(SRC_DIRS); do \
	  if [ ! -d "$$d" ]; then \
	    echo "  MISSING source dir: $$d — skipping"; \
	  else \
	    echo "  merging $$d"; \
	    cp -a "$$d"/. $(OUT_DIR)/; \
	  fi; \
	done
	@# Install pip deps into the same tree. uv sidesteps the host python
	@# symlink issue (see infra/lib/utils/python-bundling.ts for the full
	@# rationale). --only-binary :all: forces wheels so nothing tries to
	@# native-compile against the host toolchain.
	@if [ -f "$(REQS)" ]; then \
	  echo "==> uv pip install -r $(REQS)"; \
	  uv pip install \
	    --target $(OUT_DIR) \
	    --python-platform x86_64-manylinux2014 \
	    --python-version 3.12 \
	    --only-binary :all: --no-cache -q \
	    -r $(REQS); \
	else \
	  echo "  no requirements.txt at $(REQS) — skipping pip install"; \
	fi
	@# Strip .pyc, __pycache__, dist-info metadata; zip is smaller and the
	@# hash stays stable across rebuilds (pip drops timestamped metadata).
	@find $(OUT_DIR) -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
	@find $(OUT_DIR) -name '*.pyc' -delete 2>/dev/null || true
	@# Deterministic zip: sort entries + fixed mtime → same content = same hash.
	@echo "==> Zipping to $(ZIP)"
	@rm -f $(ZIP)
	@cd $(OUT_DIR) && find . -exec touch -t 197001010000 {} + && \
	  find . -type f | sort | zip -X -q -@ $(ZIP)
	@echo "==> Built $(ZIP) ($$(du -sh $(ZIP) | cut -f1))"

clean: ## Remove the staging dir and zip
	rm -rf $(OUT_DIR) $(ZIP)
