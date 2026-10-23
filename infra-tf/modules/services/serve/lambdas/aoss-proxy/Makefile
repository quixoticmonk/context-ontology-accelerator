# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# AOSS search proxy Lambda — signs sigv4 requests against the AOSS
# data-plane on behalf of the AgentCore Runtime (which can't sigv4-sign
# AOSS calls itself today).
#
# Source: packages/context-manager/lambda/aoss-search-proxy + libs/common/src
# Output: infra-tf/artifacts/lambdas/aoss-proxy.zip
#
# Mirrors the CDK bundlePython() call in serve-stack.ts: index.py imports
# coa_common (opensearch_client_kwargs, resolve_region), so libs/common/src
# and coa_common's eager-import deps MUST be bundled or the Lambda fails at
# cold start with `Runtime.ImportModuleError: No module named 'coa_common'`.

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../../../..)
ARTIFACTS := $(REPO_ROOT)/infra-tf/artifacts/lambdas
SRC_DIR   := $(REPO_ROOT)/packages/context-manager/lambda/aoss-search-proxy
COMMON    := $(REPO_ROOT)/libs/common/src
OUT_DIR   := $(ARTIFACTS)/aoss-proxy
ZIP       := $(ARTIFACTS)/aoss-proxy.zip
REQS      := $(SRC_DIR)/requirements.txt

# Matches CDK serve-stack.ts pipDeps for AossSearchProxyFn (COA v0.3.7).
# certifi: first release without the roots behind the compromised emSign
# intermediates. Each spec is quoted so `>=` is not a shell redirect.
PIP_DEPS := \
  "opensearch-py" \
  "requests-aws4auth" \
  "cedarpy" \
  "cryptography" \
  "pydantic-settings" \
  "PyJWT" \
  "requests" \
  "structlog" \
  "certifi>=2026.10.19"

.PHONY: build clean
.DEFAULT_GOAL := build

build: $(ZIP)

$(ZIP): $(shell find $(SRC_DIR) $(COMMON) -type f 2>/dev/null)
	@echo "==> Building aoss-proxy Lambda zip"
	@rm -rf $(OUT_DIR)
	@mkdir -p $(OUT_DIR)
	@cp -a $(SRC_DIR)/. $(OUT_DIR)/
	@cp -a $(COMMON)/. $(OUT_DIR)/
	@uv pip install \
	  --target $(OUT_DIR) \
	  --python-platform aarch64-manylinux2014 \
	  --python-version 3.12 \
	  --only-binary :all: --no-cache -q \
	  $(if $(wildcard $(REQS)),-r $(REQS)) \
	  $(PIP_DEPS)
	@find $(OUT_DIR) -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null || true
	@rm -f $(ZIP)
	@cd $(OUT_DIR) && find . -exec touch -t 197001010000 {} + && \
	  find . -type f | sort | zip -X -q -@ $(ZIP)
	@echo "==> Built $(ZIP)"

clean:
	rm -rf $(OUT_DIR) $(ZIP)
