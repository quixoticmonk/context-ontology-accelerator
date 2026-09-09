# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Builds and pushes the VKG (Ontop) container image to its ECR repo, then
# records the pushed image URI to infra-tf/artifacts/images/vkg.tag, which
# Terraform reads via var.image_tag_file -> local.image_uri.
#
# The ECR repo is owned by `stacks/25-ecr` (apply that before this Makefile).
# 25-ecr publishes the repository URL to /<resource_prefix>/ecr/vkg/url, which
# this Makefile reads via `aws ssm get-parameter` when ECR_REPO_URL is not
# overridden.

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c

# ── Paths (resolved relative to this Makefile) ──────────────────────
# Repo root is 5 dirs up: modules/services/vkg/image/ -> root
REPO_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))../../../../..)
CONTEXT   := $(REPO_ROOT)/packages/vkg
ARTIFACTS := $(REPO_ROOT)/infra-tf/artifacts/images
TAG_FILE  := $(ARTIFACTS)/vkg.tag

# ── Config (override on the command line) ───────────────────────────
REGION       ?= us-east-1
SSM_PREFIX   ?= /coa
IMAGE_KEY    ?= vkg
# When unset, resolve from SSM (populated by stack 25-ecr).
ECR_REPO_URL ?= $(shell aws ssm get-parameter --region $(REGION) --name $(SSM_PREFIX)/ecr/$(IMAGE_KEY)/url --query Parameter.Value --output text 2>/dev/null)
TAG          := $(shell git -C $(REPO_ROOT) rev-parse --short HEAD)

.PHONY: push clean help check-repo
.DEFAULT_GOAL := push

help: ## Show help
	@awk 'BEGIN {FS = ":.*##"; printf "\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

check-repo:
	@if [ -z "$(ECR_REPO_URL)" ]; then \
	  echo "ERROR: ECR_REPO_URL is empty and SSM lookup at $(SSM_PREFIX)/ecr/$(IMAGE_KEY)/url returned nothing."; \
	  echo "Run 'make apply-25-ecr' first, or pass ECR_REPO_URL=... explicitly."; \
	  exit 1; \
	fi

push: check-repo ## Build + push the VKG image and write the tag file
	@registry=$$(echo $(ECR_REPO_URL) | cut -d/ -f1); \
	  echo "==> Logging in to $$registry"; \
	  aws ecr get-login-password --region $(REGION) \
	    | docker login --username AWS --password-stdin "$$registry"
	@echo "==> Building $(ECR_REPO_URL):$(TAG)"
	@docker build --platform linux/arm64 -t $(ECR_REPO_URL):$(TAG) $(CONTEXT)
	@echo "==> Pushing $(ECR_REPO_URL):$(TAG)"
	@docker push $(ECR_REPO_URL):$(TAG)
	@mkdir -p $(ARTIFACTS)
	@echo "$(ECR_REPO_URL):$(TAG)" > $(TAG_FILE)
	@echo "==> Wrote $(TAG_FILE): $$(cat $(TAG_FILE))"

clean: ## Remove the tag file
	rm -f $(TAG_FILE)
