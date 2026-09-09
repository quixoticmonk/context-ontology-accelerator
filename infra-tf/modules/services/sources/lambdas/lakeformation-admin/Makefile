# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Lake Formation admin registrar Lambda — replaces the CDK
# LakeFormationAdmin custom-resource construct with a purpose-built
# function that this repo's `aws_lambda_invocation` resource drives.
#
# Handler: index.handler (boto3 is present in the Lambda runtime, no
# packaging dependencies needed).
#
# Output: infra-tf/artifacts/lambdas/lakeformation-admin.zip

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../../../..)
ARTIFACTS := $(REPO_ROOT)/infra-tf/artifacts/lambdas
SRC_DIR   := $(dir $(lastword $(MAKEFILE_LIST)))
OUT_DIR   := $(ARTIFACTS)/lakeformation-admin
ZIP       := $(ARTIFACTS)/lakeformation-admin.zip

.PHONY: build clean
.DEFAULT_GOAL := build

build: $(ZIP)

$(ZIP): $(SRC_DIR)index.py
	@echo "==> Building lakeformation-admin Lambda zip"
	@rm -rf $(OUT_DIR)
	@mkdir -p $(OUT_DIR)
	@cp $(SRC_DIR)index.py $(OUT_DIR)/
	@rm -f $(ZIP)
	@cd $(OUT_DIR) && find . -exec touch -t 197001010000 {} + && \
	  find . -type f | sort | zip -X -q -@ $(ZIP)
	@echo "==> Built $(ZIP)"

clean:
	rm -rf $(OUT_DIR) $(ZIP)
