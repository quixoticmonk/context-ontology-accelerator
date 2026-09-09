# Terraform infrastructure — Context Ontology Accelerator
#
# Layered stacks live under `stacks/`. Each stack has its own local
# state, applies in order, and reads upstream outputs from SSM.
#
# Run the layers in numeric order. See DEPLOY.md for full walkthrough.
#
#   make init-all              # once
#   make apply-00-network
#   make apply-10-foundation
#   make apply-20-namespace
#   make apply-25-ecr          # ECR repos owned before any image-consuming stack
#   make build                 # build lambda zips + push images to ECR
#   make apply-30-services     # metric-service, vkg, ontology
#   make apply-40-sources
#   make apply-50-agentcore    # serve + mcp AgentCore Runtimes
#   make apply-55-data-layer   # data-layer Lambda (needs serve runtime ARN)
#   make apply-60-api-edge     # API Gateway + CloudFront + S3 website
#   make apply-70-observability
#
# One-pass end-to-end (includes `make build` between apply-25-ecr and
# apply-30-services, so no manual step is required):
#   make up-all

SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

TF ?= terraform

# Auto-approve applies and destroys by default. Override for interactive
# review with `make apply-30-services AUTO_APPROVE=` (empty).
AUTO_APPROVE ?= -auto-approve

# ── Discovered lambda / image build targets ─────────────────────────
LAMBDA_MAKEFILES := $(shell find modules -type f -name Makefile -path '*/lambdas/*' 2>/dev/null)
LAMBDA_DIRS      := $(dir $(LAMBDA_MAKEFILES))

IMAGE_MAKEFILES  := $(shell find modules -type f -name Makefile -path '*/image/*' 2>/dev/null)
IMAGE_DIRS       := $(dir $(IMAGE_MAKEFILES))

# ── Layer names (must match directories under stacks/) ──────────────
LAYERS := 00-network 10-foundation 20-namespace 25-ecr 30-services 40-sources 50-agentcore 55-data-layer 60-api-edge 70-observability

VAR_FILE := ../../shared.tfvars

# ── Meta ────────────────────────────────────────────────────────────
.PHONY: help
help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-28s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

# ── Artifact builds ─────────────────────────────────────────────────
.PHONY: build build-lambdas build-images smithy-generate

# Both lambda zips and container images COPY from ../smithy-generated/,
# which is gitignored. Generate it once before either build runs.
REPO_ROOT       := $(abspath $(CURDIR)/..)
SMITHY_MARKER   := $(REPO_ROOT)/smithy-generated/control-plane-python-server
SMITHY_SCRIPT   := $(REPO_ROOT)/scripts/smithy-generate.sh

build: smithy-generate build-lambdas build-images ## Generate smithy models, build every Lambda zip, and every container image

smithy-generate: ## Generate smithy models under ../smithy-generated (idempotent)
	@if [ -d "$(SMITHY_MARKER)" ]; then \
	  echo "==> smithy-generate: $(SMITHY_MARKER) already present, skipping"; \
	else \
	  echo "==> smithy-generate: $(SMITHY_SCRIPT)"; \
	  bash "$(SMITHY_SCRIPT)"; \
	fi

build-lambdas: smithy-generate ## Build every Lambda zip (parallel-safe with `-j`)
	@if [ -z "$(LAMBDA_DIRS)" ]; then echo "no Lambda Makefiles yet — nothing to build"; else \
	  for d in $(LAMBDA_DIRS); do \
	    echo "==> build-lambda: $$d"; \
	    $(MAKE) -C $$d build || exit 1; \
	  done; \
	fi

build-images: smithy-generate ## Build and push every container image to ECR
	@if [ -z "$(IMAGE_DIRS)" ]; then echo "no image Makefiles yet — nothing to build"; else \
	  for d in $(IMAGE_DIRS); do \
	    echo "==> build-image: $$d"; \
	    $(MAKE) -C $$d push || exit 1; \
	  done; \
	fi

# ── Per-stack targets ───────────────────────────────────────────────
# init-%   → terraform init in stack $*
# fmt-%    → terraform fmt -check in stack $*
# plan-%   → terraform plan in stack $*
# apply-%  → terraform apply in stack $*
# destroy-%→ terraform destroy in stack $*

# NOTE: pattern-matched targets (init-%, apply-%, ...) must NOT be declared
# in .PHONY — GNU Make skips implicit/pattern-rule search for phony targets,
# which makes init-all a no-op. A FORCE prereq keeps them always-run instead.
.PHONY: FORCE
FORCE:

init-%: FORCE ## terraform init for stack %
	@echo "==> init stacks/$*"; cd stacks/$* && $(TF) init

fmt-%: FORCE ## terraform fmt -check for stack %
	@cd stacks/$* && $(TF) fmt -recursive -check -diff

plan-%: FORCE ## terraform plan for stack % (writes tfplan)
	@echo "==> plan stacks/$*"; cd stacks/$* && $(TF) plan -var-file=$(VAR_FILE) -out=tfplan

apply-%: FORCE ## terraform apply for stack % (auto-approved; unset AUTO_APPROVE for prompt)
	@echo "==> apply stacks/$*"; cd stacks/$* && $(TF) apply $(AUTO_APPROVE) -var-file=$(VAR_FILE)

apply-plan-%: FORCE ## terraform apply on a previously-generated plan
	@cd stacks/$* && $(TF) apply tfplan

destroy-%: FORCE ## terraform destroy for stack % (auto-approved; unset AUTO_APPROVE for prompt)
	@echo "==> destroy stacks/$*"; cd stacks/$* && $(TF) destroy $(AUTO_APPROVE) -var-file=$(VAR_FILE)

# ── Retain-on-destroy for DataZone (mirrors CDK RemovalPolicy.RETAIN) ─
# DataZone form types + asset types must be DISABLED before AWS will
# delete them, and prod policy is to never `terraform destroy` the
# catalog. Override the pattern rule for stack 20-namespace: state-rm
# every DataZone resource first (TF forgets them, AWS keeps them), then
# run the regular destroy for IAM/DDB/Lambda pieces.
#
# Physical resources persist in AWS after this — use
# `./scripts/nuke-coa-dev.sh` to delete the domain via
# `datazone delete-domain --skip-deletion-check` if you truly want them gone.
.PHONY: destroy-20-namespace
destroy-20-namespace: FORCE
	@echo "==> retaining DataZone resources in stacks/20-namespace"
	@cd stacks/20-namespace && for r in $$( \
	  $(TF) state list 2>/dev/null | grep -E 'datazone|dz_project_access|smus_' \
	); do \
	  echo "  ...retaining $$r"; \
	  $(TF) state rm "$$r" >/dev/null; \
	done
	@echo "==> destroy stacks/20-namespace (non-DataZone remainder)"
	@cd stacks/20-namespace && $(TF) destroy $(AUTO_APPROVE) -var-file=$(VAR_FILE)

# ── Layer-wide meta targets ─────────────────────────────────────────
.PHONY: init-all up-all down-all fmt-all
init-all: $(addprefix init-,$(LAYERS)) ## terraform init on every stack

up-all: ## Apply every stack in order, building artifacts between ECR and services
	$(MAKE) apply-00-network
	$(MAKE) apply-10-foundation
	$(MAKE) apply-20-namespace
	$(MAKE) apply-25-ecr
	$(MAKE) build
	$(MAKE) apply-30-services
	$(MAKE) apply-40-sources
	$(MAKE) apply-50-agentcore
	$(MAKE) apply-55-data-layer
	$(MAKE) apply-60-api-edge
	$(MAKE) apply-70-observability

down-all: ## Destroy every stack in reverse order (DataZone forbids full destroy — see DEPLOY.md)
	$(MAKE) destroy-70-observability
	$(MAKE) destroy-60-api-edge
	$(MAKE) destroy-55-data-layer
	$(MAKE) destroy-50-agentcore
	$(MAKE) destroy-40-sources
	$(MAKE) destroy-30-services
	$(MAKE) destroy-25-ecr
	$(MAKE) destroy-20-namespace
	$(MAKE) destroy-10-foundation
	$(MAKE) destroy-00-network

fmt-all: ## terraform fmt -check across every stack + modules
	$(TF) fmt -recursive -check -diff modules stacks

fmt-write: ## terraform fmt across every stack + modules (rewrite)
	$(TF) fmt -recursive modules stacks

# ── Clean ───────────────────────────────────────────────────────────
.PHONY: clean clean-artifacts
clean: clean-artifacts ## Remove built artifacts

clean-artifacts: ## Remove Lambda zips, image tag files, and Lambda staging dirs
	rm -rf artifacts/lambdas/* artifacts/images/*
	touch artifacts/lambdas/.gitkeep artifacts/images/.gitkeep
	@for d in $(LAMBDA_DIRS) $(IMAGE_DIRS); do \
	  $(MAKE) -C $$d clean 2>/dev/null || true; \
	done
