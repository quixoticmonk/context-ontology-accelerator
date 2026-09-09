# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Doc cleanup Lambda — bundle for packages/sources/documents/deletion.
# Handler is `cleanup_handler.handler` (not under a coa_sources.*
# package path), so bundled separately from the shared sources zip.
#
# Output: infra-tf/artifacts/lambdas/sources-doc-cleanup.zip

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../../../..)
ARTIFACTS := $(REPO_ROOT)/infra-tf/artifacts/lambdas
SRC_DIRS  := $(REPO_ROOT)/packages/sources/src/coa_sources/documents/deletion $(REPO_ROOT)/libs/common/src
OUT_DIR   := $(ARTIFACTS)/sources-doc-cleanup
ZIP       := $(ARTIFACTS)/sources-doc-cleanup.zip
REQS      := $(REPO_ROOT)/packages/sources/documents/deletion/requirements.txt

.PHONY: build clean
.DEFAULT_GOAL := build

build: $(ZIP)

$(ZIP): $(shell find $(SRC_DIRS) -type f 2>/dev/null)
	@echo "==> Building sources-doc-cleanup Lambda zip"
	@rm -rf $(OUT_DIR)
	@mkdir -p $(OUT_DIR)
	@for d in $(SRC_DIRS); do \
	  if [ -d "$$d" ]; then cp -a "$$d"/. $(OUT_DIR)/; fi; \
	done
	@if [ -f "$(REQS)" ]; then \
	  uv pip install \
	    --target $(OUT_DIR) \
	    --python-platform aarch64-manylinux2014 \
	    --python-version 3.12 \
	    --only-binary :all: --no-cache -q \
	    -r $(REQS); \
	fi
	@find $(OUT_DIR) -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null || true
	@rm -f $(ZIP)
	@cd $(OUT_DIR) && find . -exec touch -t 197001010000 {} + && \
	  find . -type f | sort | zip -X -q -@ $(ZIP)
	@echo "==> Built $(ZIP)"

clean:
	rm -rf $(OUT_DIR) $(ZIP)
