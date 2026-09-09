# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# AOSS search proxy Lambda — signs sigv4 requests against the AOSS
# data-plane on behalf of the AgentCore Runtime (which can't sigv4-sign
# AOSS calls itself today).
#
# Source: packages/context-manager/lambda/aoss-search-proxy
# Output: infra-tf/artifacts/lambdas/aoss-proxy.zip

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../../../..)
ARTIFACTS := $(REPO_ROOT)/infra-tf/artifacts/lambdas
SRC_DIR   := $(REPO_ROOT)/packages/context-manager/lambda/aoss-search-proxy
OUT_DIR   := $(ARTIFACTS)/aoss-proxy
ZIP       := $(ARTIFACTS)/aoss-proxy.zip
REQS      := $(SRC_DIR)/requirements.txt

.PHONY: build clean
.DEFAULT_GOAL := build

build: $(ZIP)

$(ZIP): $(shell find $(SRC_DIR) -type f 2>/dev/null)
	@echo "==> Building aoss-proxy Lambda zip"
	@rm -rf $(OUT_DIR)
	@mkdir -p $(OUT_DIR)
	@cp -a $(SRC_DIR)/. $(OUT_DIR)/
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
