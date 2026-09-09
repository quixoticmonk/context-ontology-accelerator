# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Doc ingestion trigger Lambda — small dedicated bundle for the
# packages/sources/documents/trigger source. Bundled separately from
# the shared "sources" zip because its handler is `index.handler` (not
# a coa_sources.* module path).
#
# Output: infra-tf/artifacts/lambdas/sources-doc-trigger.zip

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../../../..)
ARTIFACTS := $(REPO_ROOT)/infra-tf/artifacts/lambdas
SRC_DIRS  := $(REPO_ROOT)/packages/sources/documents/trigger $(REPO_ROOT)/libs/common/src
OUT_DIR   := $(ARTIFACTS)/sources-doc-trigger
ZIP       := $(ARTIFACTS)/sources-doc-trigger.zip
REQS      := $(REPO_ROOT)/packages/sources/documents/trigger/requirements.txt

.PHONY: build clean
.DEFAULT_GOAL := build

build: $(ZIP)

$(ZIP): $(shell find $(SRC_DIRS) -type f 2>/dev/null)
	@echo "==> Building sources-doc-trigger Lambda zip"
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
