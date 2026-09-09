# Terraform Infrastructure

Terraform port of the CDK infrastructure in [`../infra/`](../infra/). See
[`../TERRAFORM_MIGRATION_PLAN.md`](../TERRAFORM_MIGRATION_PLAN.md) for the
full CDK → TF resource mapping, phasing, and known gotchas.

**Status:** Phases 0–7 complete. 17 modules landed, ~17,650 lines HCL.
Full-graph `terraform validate` passes; `terraform plan` builds the
graph without errors.

## Structure

```
infra-tf/
├── terraform.tf              # required_version + required_providers
├── providers.tf              # aws (regional) + aws.us_east_1 alias
├── variables.tf              # inputs — alphabetized
├── locals.tf                 # name_prefix, common_tags, brand_env, custom_domain
├── main.tf                   # module wiring (phase-commented placeholders)
├── outputs.tf                # public URLs, ARNs, IDs
├── terraform.tfvars.example  # copy to terraform.tfvars and edit
├── Makefile                  # build/plan/apply — fans out to per-module Makefiles
├── artifacts/                # gitignored — built Lambda zips + image tag files
│   ├── lambdas/
│   └── images/
└── modules/                  # 17 modules across 3 categories
    ├── foundation/           # network, storage, authnz, auth-idp, guardrail, edge-waf, web
    ├── services/             # namespace, api, sources, ontology, metric-service, vkg, serve, mcp, data-layer
    └── observability/        # shared CloudWatch alarm module (Phase 7)
```

Single-root layout — no `envs/` split. Environment is set via `env`
variable (default `dev`), matching the CDK's context-driven model.

## Commands

```bash
make help              # list all targets
make init              # terraform init
make fmt-write         # terraform fmt -recursive
make validate          # terraform validate
make build             # build every Lambda zip + push every container image
make plan              # build + terraform plan (writes tfplan)
make apply             # build + terraform apply
make apply-plan        # apply a previously-generated tfplan (no rebuild)
make clean             # remove built artifacts
```

Artifacts are always built before `plan` and `apply` unless you explicitly
run `make apply-plan` on a stored plan file.

## First-time deployment

Fresh accounts have a chicken-and-egg problem: ECR repositories must
exist before container images can be pushed to them. The first apply
runs in two passes.

```bash
# 1. Init + review + apply ECR repos only (targeted).
#    Which -target flags depend on which service modules are enabled;
#    the plan document lists all seven images.
make init
terraform apply \
  -target='module.vkg.aws_ecr_repository.this' \
  -target='module.ontology.aws_ecr_repository.this' \
  # ...one per image module

# 2. Build + push all images.
make build-images

# 3. Full apply.
make apply
```

After the first deploy, `make apply` alone is enough (ECR repos exist,
image URIs are stable).

## Configuration

Copy the example and edit:

```bash
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars
```

`terraform.tfvars` is gitignored. Every knob has a documented default in
`variables.tf`; only override what differs.

Common overrides:

| Variable | Default | Override when |
|---|---|---|
| `resource_prefix` | `coa` | Multiple deployments share an account |
| `env` | `dev` | Not deploying dev |
| `region` | `us-east-1` | Not deploying us-east-1 (also update `azs`) |
| `idp_type` | `COGNITO` | Federating SAML or using external OIDC direct |
| `initial_admin_email` | `nobody@amazon.com` | Always — pick a real address |
| `ui_domain_name` et al. | `null` | Serving a real domain (all-or-nothing group) |
| `lambda_reserved_concurrency` | `5` | Account has reduced Lambda concurrent-executions quota (set to `0`) |

## State

**Local state.** `terraform.tfstate` lives in this directory. This is
fine for a single-operator, single-machine setup. Migrate to an S3
backend when the deployment moves to a shared context (multiple
operators, CI/CD, or team ownership).

## Cross-cutting patterns

- **Naming.** Every physical resource name starts with
  `${resource_prefix}-${env}` — computed in `locals.tf` as
  `local.name_prefix`.
- **Tags.** Applied via `default_tags` on both providers (`Environment`,
  `ManagedBy`, `Project`). Each module adds its own `Component` tag on
  top.
- **Brand env vars.** `GRAPH_BASE_URI` and `EVENT_SOURCE_PREFIX` are
  injected into every Lambda and ECS container (CDK equivalent:
  `BrandEnvAspect`). Computed in `locals.tf` as `local.brand_env` and
  merged into each module's environment maps.
- **SSM parameters.** Kept for **runtime** cross-service reads by
  Lambda/container code. Deploy-time cross-module references use direct
  module outputs (idiomatic Terraform).
- **Two providers.** `aws` at `var.region`; `aws.us_east_1` for
  CloudFront, edge WAF, and any ACM cert consumed by CloudFront.

## Style compliance

Enforced (matches the `terraform-style-guide` skill):

- Alphabetized variables and outputs
- `description` → `type` → `default` → `sensitive` field order
- 2-space indent
- `for_each` over `count` for multi-resource creation
- Separate `aws_iam_policy` + `aws_iam_role_policy_attachment` (no inline)
- `this` for singleton resources within a module
- Block order inside resources: meta-arguments → arguments → nested
  blocks → `tags` → `lifecycle`

Run `make fmt` (check) or `make fmt-write` (rewrite) before committing.
