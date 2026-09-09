# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# sources/preprocessing container image (Lambda DockerImageFunction).
# ECR repo owned by stacks/25-ecr; URL resolved from SSM.

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

REPO_ROOT   := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../../../..)
DOCKERFILE  := $(REPO_ROOT)/packages/sources/documents/preprocessing/Dockerfile
ARTIFACTS   := $(REPO_ROOT)/infra-tf/artifacts/images
TAG_FILE    := $(ARTIFACTS)/sources-preprocessing.tag

REGION       ?= us-east-1
SSM_PREFIX   ?= /coa
IMAGE_KEY    ?= sources-preprocessing
ECR_REPO_URL ?= $(shell aws ssm get-parameter --region $(REGION) --name $(SSM_PREFIX)/ecr/$(IMAGE_KEY)/url --query Parameter.Value --output text 2>/dev/null)
IMAGE_TAG    ?= $(shell git -C $(REPO_ROOT) rev-parse --short HEAD 2>/dev/null || echo latest)
# Lambda DockerImageFunctions must be x86_64 or arm64; sources module
# uses default (x86_64) for this one — keep consistent with the CDK.
PLATFORM     := linux/amd64

.PHONY: build push tag clean help check-repo
.DEFAULT_GOAL := help

help: ## Show help
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

check-repo:
	@if [ -z "$(ECR_REPO_URL)" ]; then \
	  echo "ERROR: ECR_REPO_URL empty; run 'make apply-25-ecr' or pass explicitly."; \
	  exit 1; \
	fi

build: check-repo ## Build the preprocessing image
	@echo "==> Building $(ECR_REPO_URL):$(IMAGE_TAG) ($(PLATFORM))"
	docker build --platform $(PLATFORM) -f $(DOCKERFILE) -t $(ECR_REPO_URL):$(IMAGE_TAG) $(REPO_ROOT)

push: build ## Build + push + write tag file
	@registry=$$(echo $(ECR_REPO_URL) | cut -d/ -f1); \
	  echo "==> Logging in to $$registry"; \
	  aws ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin "$$registry"
	@echo "==> Pushing $(ECR_REPO_URL):$(IMAGE_TAG)"
	docker push $(ECR_REPO_URL):$(IMAGE_TAG)
	@mkdir -p $(ARTIFACTS)
	@printf '%s' "$(ECR_REPO_URL):$(IMAGE_TAG)" > $(TAG_FILE)
	@echo "==> Wrote $(TAG_FILE): $$(cat $(TAG_FILE))"

clean:
	rm -f $(TAG_FILE)
