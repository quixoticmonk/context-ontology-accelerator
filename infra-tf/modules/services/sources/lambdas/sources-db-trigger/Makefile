# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Small dedicated bundle for the sources-db-scan-trigger Lambda.
# The trigger is packages/sources/database/trigger — an SQS→SFN
# start-execution shim with no third-party deps. Kept separate from
# the big shared "sources" zip because the trigger is x86_64 while
# every other sources Lambda is arm64, and its 30s/128MB budget
# doesn't need the pip/wheel overhead.
#
# Output: infra-tf/artifacts/lambdas/sources-db-trigger.zip

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../../../..)
ARTIFACTS := $(REPO_ROOT)/infra-tf/artifacts/lambdas
SRC_DIR   := $(REPO_ROOT)/packages/sources/database/trigger
OUT_DIR   := $(ARTIFACTS)/sources-db-trigger
ZIP       := $(ARTIFACTS)/sources-db-trigger.zip

REQS := $(SRC_DIR)/requirements.txt

.PHONY: build clean
.DEFAULT_GOAL := build

build: $(ZIP)

$(ZIP): $(shell find $(SRC_DIR) -type f 2>/dev/null)
	@echo "==> Building sources-db-trigger Lambda zip"
	@rm -rf $(OUT_DIR)
	@mkdir -p $(OUT_DIR)
	@cp -a $(SRC_DIR)/. $(OUT_DIR)/
	@if [ -f "$(REQS)" ]; then \
	  echo "==> uv pip install -r $(REQS)"; \
	  uv pip install \
	    --target $(OUT_DIR) \
	    --python-platform x86_64-manylinux2014 \
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
