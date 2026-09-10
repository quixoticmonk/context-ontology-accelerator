# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Cognito callback URL patcher — replaces the CDK custom-resource
# Lambda that used to append the CloudFront callback URL to the user
# pool client after the distribution came up.
#
# Handler: index.handler (boto3 present in the Lambda runtime).
# Output:  infra-tf/artifacts/lambdas/cognito-callback-patch.zip

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../../../..)
ARTIFACTS := $(REPO_ROOT)/infra-tf/artifacts/lambdas
SRC_DIR   := $(dir $(lastword $(MAKEFILE_LIST)))
OUT_DIR   := $(ARTIFACTS)/cognito-callback-patch
ZIP       := $(ARTIFACTS)/cognito-callback-patch.zip

.PHONY: build clean
.DEFAULT_GOAL := build

build: $(ZIP)

$(ZIP): $(SRC_DIR)index.py
	@echo "==> Building cognito-callback-patch Lambda zip"
	@rm -rf $(OUT_DIR)
	@mkdir -p $(OUT_DIR)
	@cp $(SRC_DIR)index.py $(OUT_DIR)/
	@rm -f $(ZIP)
	@cd $(OUT_DIR) && find . -exec touch -t 197001010000 {} + && \
	  find . -type f | sort | zip -X -q -@ $(ZIP)
	@echo "==> Built $(ZIP)"

clean:
	rm -rf $(OUT_DIR) $(ZIP)
