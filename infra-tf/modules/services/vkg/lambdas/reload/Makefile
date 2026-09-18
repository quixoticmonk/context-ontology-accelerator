# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Reload Lambda code bundle for the VKG module.
#
# Source: infra-tf/modules/services/vkg/lambdas/reload/index.py, vendored
# into this module. The handler imports only the stdlib plus boto3
# (provided by the Lambda Python 3.12 runtime), so there are NO pip
# dependencies to install — the zip is just index.py.
#
# Output: infra-tf/artifacts/lambdas/vkg-reload.zip
#
# Rebuilt via `make build`. The zip's content hash triggers a Lambda
# redeploy via filebase64sha256() in locals.tf.

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# ── Paths (resolved relative to this Makefile) ──────────────────────
# Repo root is 6 dirs up: modules/services/vkg/lambdas/reload/ -> root
REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../../../..)
ARTIFACTS := $(REPO_ROOT)/infra-tf/artifacts/lambdas
OUT_DIR   := $(ARTIFACTS)/vkg-reload
ZIP       := $(ARTIFACTS)/vkg-reload.zip
# Vendored alongside this Makefile after CDK removal (was
# $(REPO_ROOT)/infra/lambda/vkg-reload/index.py; that tree is gone).
SRC       := $(REPO_ROOT)/infra-tf/modules/services/vkg/lambdas/reload/index.py

.PHONY: build clean help
.DEFAULT_GOAL := build

help: ## Show help
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

build: $(ZIP) ## Build vkg-reload.zip

$(ZIP): $(SRC)
	@echo "==> Building vkg-reload Lambda zip"
	@test -f "$(SRC)" || { echo "  MISSING source: $(SRC)"; exit 1; }
	@rm -rf $(OUT_DIR)
	@mkdir -p $(OUT_DIR)
	@cp -a "$(SRC)" $(OUT_DIR)/index.py
	@# Deterministic zip: fixed mtime + sorted entries -> stable hash.
	@echo "==> Zipping to $(ZIP)"
	@rm -f $(ZIP)
	@cd $(OUT_DIR) && find . -exec touch -t 197001010000 {} + && \
	  find . -type f | sort | zip -X -q -@ $(ZIP)
	@echo "==> Built $(ZIP) ($$(du -sh $(ZIP) | cut -f1))"

clean: ## Remove the staging dir and zip
	rm -rf $(OUT_DIR) $(ZIP)
