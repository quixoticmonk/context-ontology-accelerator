# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Shared "sources" zip — used by dbConnector, federationProvisioner,
# dbScanReaper, bulkReviewWorker (this sub-turn's DB pipeline), plus
# docCleanup and docTrigger (sub-turn 3) and sourcesApi (sub-turn 4).
#
# Superset bundle (matches CDK bundlePython() with the widest srcDirs
# from any Lambda in this module — bulkReviewWorker):
#   - packages/sources/database/bulk_review_worker
#   - packages/sources/src
#   - libs/common/src
#   - smithy-generated/control-plane-python-server
#
# Output: infra-tf/artifacts/lambdas/sources.zip

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

REPO_ROOT   := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../../../..)
ARTIFACTS   := $(REPO_ROOT)/infra-tf/artifacts/lambdas
OUT_DIR     := $(ARTIFACTS)/sources
ZIP         := $(ARTIFACTS)/sources.zip

SRC_DIRS := \
  $(REPO_ROOT)/packages/sources/database/bulk_review_worker \
  $(REPO_ROOT)/packages/sources/src \
  $(REPO_ROOT)/libs/common/src \
  $(REPO_ROOT)/smithy-generated/control-plane-python-server

REQS := $(REPO_ROOT)/packages/sources/requirements.txt

.PHONY: build clean
.DEFAULT_GOAL := build

build: $(ZIP)

$(ZIP): $(REQS) $(shell find $(SRC_DIRS) -type f 2>/dev/null)
	@echo "==> Building sources Lambda zip"
	@rm -rf $(OUT_DIR)
	@mkdir -p $(OUT_DIR)
	@for d in $(SRC_DIRS); do \
	  if [ -d "$$d" ]; then echo "  merging $$d"; cp -a "$$d"/. $(OUT_DIR)/; \
	  else echo "  MISSING $$d — skipping"; fi; \
	done
	@if [ -f "$(REQS)" ]; then \
	  echo "==> uv pip install -r $(REQS)"; \
	  uv pip install \
	    --target $(OUT_DIR) \
	    --python-platform aarch64-manylinux2014 \
	    --python-version 3.12 \
	    --only-binary :all: --no-cache -q \
	    -r $(REQS); \
	fi
	@find $(OUT_DIR) -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null || true
	@find $(OUT_DIR) -name '*.pyc' -delete 2>/dev/null || true
	@echo "==> Zipping to $(ZIP)"
	@rm -f $(ZIP)
	@cd $(OUT_DIR) && find . -exec touch -t 197001010000 {} + && \
	  find . -type f | sort | zip -X -q -@ $(ZIP)
	@echo "==> Built $(ZIP) ($$(du -sh $(ZIP) | cut -f1))"

clean:
	rm -rf $(OUT_DIR) $(ZIP)
