# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Produces the merged OpenAPI spec at
# infra-tf/artifacts/openapi/merged.json. The api Terraform module
# reads it and injects Lambda proxy integrations per path in HCL.
#
# Discovery: the top-level infra-tf/Makefile picks this up automatically
# because it's under modules/**/lambdas/*/Makefile? NO — this lives
# under openapi/, so the top-level Makefile currently ignores it.
# See infra-tf/Makefile — the discovery glob may need extending to
# `modules/**/openapi/Makefile` before phase 5 apply.

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../../..)
CP_SPEC   := $(REPO_ROOT)/smithy-generated/openapi/openapi/ControlPlaneService.openapi.json
DL_SPEC   := $(REPO_ROOT)/smithy-generated/openapi/openapi/DataLayerService.openapi.json
OUT       := $(REPO_ROOT)/infra-tf/artifacts/openapi/merged.json

# Override at invocation time: `make CORS_ORIGIN=https://app.example.com`
CORS_ORIGIN ?= *

.PHONY: build clean
.DEFAULT_GOAL := build

build: $(OUT)

$(OUT): merge.py $(CP_SPEC) $(DL_SPEC)
	@echo "==> Merging OpenAPI specs (CorsOrigin=$(CORS_ORIGIN))"
	@python3 merge.py \
	  --control-plane "$(CP_SPEC)" \
	  --data-layer "$(DL_SPEC)" \
	  --cors-origin "$(CORS_ORIGIN)" \
	  --output "$(OUT)"

clean:
	rm -f $(OUT)
