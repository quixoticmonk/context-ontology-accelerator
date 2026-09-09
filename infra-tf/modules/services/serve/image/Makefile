# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# serve/context-manager container image build + push.
#
# Shares the packages/context-manager Dockerfile with the mcp module —
# the same image content, pushed to a separate ECR repo
# (coa-dev-context-manager) so serve and mcp can be deployed/rolled
# back independently.
#
# ECR repo owned by stacks/25-ecr; URL resolved from SSM.

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

REPO_ROOT   := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../../..)
DOCKERFILE  := $(REPO_ROOT)/packages/context-manager/Dockerfile
ARTIFACTS   := $(REPO_ROOT)/infra-tf/artifacts/images
TAG_FILE    := $(ARTIFACTS)/context-manager.tag

REGION       ?= us-east-1
SSM_PREFIX   ?= /coa
IMAGE_KEY    ?= context-manager
ECR_REPO_URL ?= $(shell aws ssm get-parameter --region $(REGION) --name $(SSM_PREFIX)/ecr/$(IMAGE_KEY)/url --query Parameter.Value --output text 2>/dev/null)
IMAGE_TAG    ?= $(shell git -C $(REPO_ROOT) rev-parse --short HEAD 2>/dev/null || echo latest)
PLATFORM     := linux/arm64

.PHONY: build push tag clean help check-repo
.DEFAULT_GOAL := help

help: ## Show help
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

check-repo:
	@if [ -z "$(ECR_REPO_URL)" ]; then \
	  echo "ERROR: ECR_REPO_URL empty and SSM lookup at $(SSM_PREFIX)/ecr/$(IMAGE_KEY)/url returned nothing."; \
	  echo "Run 'make apply-25-ecr' first, or pass ECR_REPO_URL=... explicitly."; \
	  exit 1; \
	fi

build: check-repo ## Build the context-manager image for linux/arm64
	@echo "==> Building $(ECR_REPO_URL):$(IMAGE_TAG) ($(PLATFORM))"
	docker build \
	  --platform $(PLATFORM) \
	  -f $(DOCKERFILE) \
	  -t $(ECR_REPO_URL):$(IMAGE_TAG) \
	  $(REPO_ROOT)

login: check-repo ## Authenticate Docker to the ECR registry
	@registry=$$(echo $(ECR_REPO_URL) | cut -d/ -f1); \
	  echo "==> Logging in to $$registry"; \
	  aws ecr get-login-password --region $(REGION) \
	    | docker login --username AWS --password-stdin "$$registry"

push: build login tag ## Build, push, and write the tag file
	@echo "==> Pushing $(ECR_REPO_URL):$(IMAGE_TAG)"
	docker push $(ECR_REPO_URL):$(IMAGE_TAG)

tag: check-repo ## Write the deployed image reference to the tag file
	@mkdir -p $(ARTIFACTS)
	@printf '%s' "$(ECR_REPO_URL):$(IMAGE_TAG)" > $(TAG_FILE)
	@echo "==> Wrote $(TAG_FILE): $$(cat $(TAG_FILE))"

clean: ## Remove the tag file
	rm -f $(TAG_FILE)
