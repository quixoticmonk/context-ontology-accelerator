# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Lambda code bundle for the data-layer module.
#
# The single data-layer API Lambda runs from this zip. It mirrors the
# CDK bundlePython() invocation in data-layer-stack.ts, which combines
# two source directories and three pip deps into one asset:
#
#   - packages/data-layer/src   → the API handler (coa_data_layer)
#   - libs/common/src           → shared config + logging (coa_common)
#
# The handler imports from `coa_common`, whose package __init__ eagerly
# imports pydantic, pydantic-settings and structlog — so those MUST be
# bundled or the Lambda ImportModuleErrors at cold start. boto3/botocore
# are provided by the Lambda runtime and are not bundled.
#
# Output: infra-tf/artifacts/lambdas/data-layer.zip
#
# Rebuilt via `make build-lambdas` from the top-level Makefile. The
# resulting zip's content hash triggers Lambda redeploys via
# filebase64sha256() in main.tf.

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# ── Paths (all resolved relative to this Makefile) ──────────────────
# Repo root is 6 dirs up: modules/services/data-layer/lambdas/data-layer/ → root
REPO_ROOT   := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../../../..)
ARTIFACTS   := $(REPO_ROOT)/infra-tf/artifacts/lambdas
OUT_DIR     := $(ARTIFACTS)/data-layer
ZIP         := $(ARTIFACTS)/data-layer.zip

# Source directories to merge into the asset root.
SRC_DIRS := \
  $(REPO_ROOT)/packages/data-layer/src \
  $(REPO_ROOT)/libs/common/src

# pip requirements — matches CDK's pipDeps in data-layer-stack.ts.
# The package's own requirements.txt is empty; these are the transitive
# deps pulled in by importing coa_common.
PIP_DEPS := pydantic pydantic-settings structlog

.PHONY: build clean help
.DEFAULT_GOAL := build

help: ## Show help
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: $(ZIP) ## Build data-layer.zip

$(ZIP): $(shell find $(SRC_DIRS) -type f 2>/dev/null)
	@echo "==> Building data-layer Lambda zip"
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
	@echo "==> uv pip install $(PIP_DEPS)"
	@uv pip install \
	  --target $(OUT_DIR) \
	  --python-platform x86_64-manylinux2014 \
	  --python-version 3.12 \
	  --only-binary :all: --no-cache -q \
	  $(PIP_DEPS)
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
