# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# API Gateway CORS patcher — replaces the CDK UpdateApiCors4XX +
# UpdateApiCors5XX + RedeployApi custom resources.
#
# Handler: index.handler (boto3 present in the Lambda runtime).
# Output:  infra-tf/artifacts/lambdas/api-cors-patch.zip

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../../../..)
ARTIFACTS := $(REPO_ROOT)/infra-tf/artifacts/lambdas
SRC_DIR   := $(dir $(lastword $(MAKEFILE_LIST)))
OUT_DIR   := $(ARTIFACTS)/api-cors-patch
ZIP       := $(ARTIFACTS)/api-cors-patch.zip

.PHONY: build clean
.DEFAULT_GOAL := build

build: $(ZIP)

$(ZIP): $(SRC_DIR)index.py
	@echo "==> Building api-cors-patch Lambda zip"
	@rm -rf $(OUT_DIR)
	@mkdir -p $(OUT_DIR)
	@cp $(SRC_DIR)index.py $(OUT_DIR)/
	@rm -f $(ZIP)
	@cd $(OUT_DIR) && find . -exec touch -t 197001010000 {} + && \
	  find . -type f | sort | zip -X -q -@ $(ZIP)
	@echo "==> Built $(ZIP)"

clean:
	rm -rf $(OUT_DIR) $(ZIP)
