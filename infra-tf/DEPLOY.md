# Context Ontology Accelerator — Terraform Deployment

Fresh deploy, single region (us-east-1), local state, **layered stacks**.

The infrastructure is split into 10 sequential stacks under `stacks/`.
Each stack has its own local state and reads upstream outputs from
SSM Parameter Store. Numeric order matches apply order end-to-end.

---

## 0. Prereqs

```bash
terraform version    # >= 1.14  (action blocks used in 40-sources)
aws --version
docker --version
uv --version
python3 --version    # 3.12+
jq --version
java -version        # 17+ (Smithy codegen runs on the JVM)
node -v              # 20+ (web-app build)
pnpm -v              # 9+ (workspace-aware; npm/yarn WILL NOT WORK)

export AWS_PROFILE=your-profile-name
aws sts get-caller-identity
```

If `java` isn't on PATH (macOS ships without a JDK), install and expose it:

```bash
brew install openjdk@21

# Session only (add to ~/.zshrc for persistence)
export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"   # Apple Silicon
# export PATH="/usr/local/opt/openjdk@21/bin:$PATH"    # Intel

java -version   # should print openjdk 21
```

`make build` invokes `scripts/smithy-generate.sh` before building any Lambda
zip or container image; the codegen output (`../smithy-generated/`) is
gitignored, so a first-time or clean checkout requires Java to be present.

The repo is a **pnpm workspace** — the web-app's `package.json` uses the
`workspace:*` protocol that only pnpm (not npm or yarn) understands. Install
pnpm before running `make build-web` or `make up-all`:

```bash
brew install pnpm            # or: npm install -g pnpm
pnpm -v                      # should print 9+
```

### Terraform plugin cache (recommended)

Each stack has its own `.terraform/` directory. Without a shared cache,
`terraform init` re-downloads the aws/awscc/time/external/etc. providers
into every stack — ~1 GB of duplicated binaries and slow first-inits.
Point Terraform at a shared cache once:

```bash
mkdir -p ~/.terraform.d/plugin-cache

cat >> ~/.terraformrc <<'EOF'
plugin_cache_dir   = "$HOME/.terraform.d/plugin-cache"
disable_checkpoint = true
EOF
```

Or, per-session:
```bash
export TF_PLUGIN_CACHE_DIR="$HOME/.terraform.d/plugin-cache"
```

`make init-all` will now populate the cache on the first stack and hard-link
subsequent stacks' providers from it.

---

## 1. Configure

```bash
cd <repo-root>/infra-tf

cp shared.tfvars.example shared.tfvars
$EDITOR shared.tfvars
```

At minimum set:

```hcl
resource_prefix     = "coa"
env                 = "dev"
region              = "us-east-1"
azs                 = ["us-east-1a", "us-east-1b"]   # both must be AgentCore-supported
initial_admin_email = "you@yourcompany.com"

idp_type = "COGNITO"     # or "SAML" | "OIDC"
```

**AgentCore AZ resolution is automatic.** Stack `00-network` queries
`DescribeAvailabilityZones` at plan time and picks AZs whose *zone IDs*
are in AgentCore's supported set (`use1-az1`, `use1-az2`, `use1-az4` in
us-east-1) — intersected with the AOSS VPC endpoint's AZs so both
services land where they can operate. Resolved names publish to
`/coa/network/agentcore-supported-az-names` and are consumed by
stack `50-agentcore` via SSM. If your account resolves < 2 supported
AZs, `terraform plan` on stack `00-network` fails loudly with a
concrete zone-id list, before any resource is created.

The `azs` line above is used only in unrestricted regions; in
restricted regions the resolver wins.

To update the supported zone map when AWS expands AgentCore coverage,
edit `agentcore_supported_zone_ids` in `stacks/00-network/locals.tf`.

---

## 2. Init every stack

```bash
make init-all
```

---

## 3. Apply the layers in order

`make apply-*` targets pass `-auto-approve` by default. To review a plan
interactively, unset it for that invocation:
```bash
make apply-30-services AUTO_APPROVE=
```
Or use `make plan-30-services` followed by `make apply-plan-30-services`.


### 3a. Foundation

```bash
make apply-00-network       # VPC, subnets, SGs, Cloud Map ns
make apply-10-foundation    # S3, DDB, OpenSearch, Neptune, Cognito, Guardrail, WAF
make apply-20-namespace     # DataZone + deletion pipeline
```

### 3b. ECR repositories

Stack 25 owns every image repository. It runs *before* `make build`
so image pushes have a valid target. Downstream stacks read the
repo URLs from SSM — there is no two-phase apply.

```bash
make apply-25-ecr
```

### 3c. Build artifacts

Lambda zips + container images. Every ECR repo the images target
already exists.

```bash
# Log Docker in to ECR (once per session)
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
      $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com

make build

# Verify
ls -la artifacts/lambdas/     # expect 9 .zip files
ls -la artifacts/images/      # expect 3 .tag files (ontology, vkg, mcp)
```

### 3d. Everything, one pass

`make up-all` sequences the full apply, including `make build` between
ECR and services — no manual step in the middle:

```bash
make up-all
```

Under the hood:
```
apply-00-network
  → apply-10-foundation
  → build-lambdas                            # 20-namespace needs control-plane.zip
  → apply-20-namespace
  → apply-25-ecr
  → build-images                             # ECR repos now exist for pushes
  → apply-30-services                        # metric-service, vkg, ontology
  → apply-40-sources                         # sources (ingestion, discovery, KG build)
  → apply-50-agentcore                       # serve + mcp AgentCore Runtimes
  → apply-55-data-layer                      # data-layer Lambda (needs serve ARN)
  → build-web                                # Vite build → packages/web-app/dist
  → apply-60-api-edge                        # API Gateway + CloudFront + uploads dist/ to S3
  → apply-70-observability                   # CloudWatch alarms
```

Or run any layer individually with `make apply-<layer>`.

---

## 4. Post-deploy verification

```bash
API_ENDPOINT=$(cd stacks/60-api-edge && terraform output -raw api_endpoint)
CF_DOMAIN=$(cd stacks/60-api-edge && terraform output -raw cloudfront_distribution_domain_name)
SERVE_ARN=$(cd stacks/50-agentcore && terraform output -raw serve_runtime_arn)
MCP_ARN=$(cd stacks/50-agentcore && terraform output -raw mcp_runtime_arn)

echo "API:     $API_ENDPOINT"
echo "UI:      https://$CF_DOMAIN"
echo "Serve:   $SERVE_ARN"
echo "MCP:     $MCP_ARN"

curl -sI "https://$CF_DOMAIN" | head -1
curl -s "$API_ENDPOINT/health"

aws bedrock-agentcore-control get-agent-runtime \
  --agent-runtime-id "$(echo $SERVE_ARN | awk -F/ '{print $NF}')"

aws bedrock-agentcore-control get-agent-runtime \
  --agent-runtime-id "$(echo $MCP_ARN | awk -F/ '{print $NF}')"
```

---

## 5. Retrieve initial admin credentials

```bash
cd stacks/10-foundation
terraform output -raw initial_admin_temp_password 2>/dev/null || \
  aws cognito-idp admin-get-user \
    --user-pool-id $(terraform output -raw user_pool_id 2>/dev/null) \
    --username admin@example.com
```

Log in at `https://$CF_DOMAIN`. Cognito forces a password reset on first login.

---

## 6. Ongoing deploys

Same pattern; only re-apply stacks whose code or artifacts changed.

```bash
# Rebuild all artifacts + apply everything
make build
make up-all

# Or one layer at a time
make build-lambdas
make apply-30-services
```

Rebuild a single Lambda or image without full `make build`:

```bash
make -C modules/services/namespace/lambdas/control-plane build
make -C modules/services/vkg/image push
```

The image Makefiles resolve the ECR repo URL from SSM
(`/coa/ecr/<name>/url`), so you never need to look it up by hand.

---

## 7. Destroy (non-prod only)

DataZone tree has `lifecycle { prevent_destroy = true }` in the
namespace module. Full destroy requires shell scripting around
those resources. Reverse-order destroy of everything else:

```bash
# Everything downstream of DataZone
make destroy-70-observability
make destroy-50-agentcore
make destroy-60-api-edge
make destroy-40-sources
make destroy-30-services
make destroy-25-ecr         # non-prod repos have force_delete=true

# Then clean DataZone manually via console — projects/environments/domain
# have lifecycle { prevent_destroy = true } and must be removed by hand.

# Then foundation + network
make destroy-20-namespace   # will fail on protected DataZone; clean manually first
make destroy-10-foundation
make destroy-00-network
```

Or single-command reverse-order (will halt at DataZone):

```bash
make down-all
```

---

## 8. Lake Formation admin registration

Stack 40-sources registers the `sources-federation-provisioner` role as
a Lake Formation data-lake admin using a purpose-built Lambda invoked
via the AWS provider's [`aws_lambda_invoke`
action](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/actions/lambda_invoke).
The Lambda merges the role into `DataLakeAdmins` non-destructively —
existing admins are preserved.

Files involved:
```
modules/services/sources/lakeformation_admin.tf                  # Lambda + IAM + action
modules/services/sources/lambdas/lakeformation-admin/index.py    # Python handler
modules/services/sources/lambdas/lakeformation-admin/Makefile    # zip packager
```

The action fires on `after_create` / `after_update` of a
`terraform_data` anchor whose input is the target role ARN. Terraform
actions don't yet support `before_destroy`, so the LF admin entry stays
in the settings after `terraform destroy` — the role itself is deleted,
so the dangling entry is harmless. To prune manually:
```bash
aws lakeformation get-data-lake-settings --region us-east-1
# ...edit DataLakeAdmins to remove the deleted role ARN, then...
aws lakeformation put-data-lake-settings --cli-input-json file://settings.json
```

---

## 9. Full reset (development / iteration)

If a partial apply left orphans that block a fresh run — or you're
recovering from a prior CDK deploy — nuke every `coa-dev-*` resource
this repo's stacks manage plus every stack's local state:

```bash
./scripts/nuke-coa-dev.sh
# then start from step 3 again
```

Env overrides:
```bash
REGION=us-west-2 PREFIX=coa-prod- DOMAIN_NAME=coa-prod-smus-catalog SSM_ROOT=/coa \
  ./scripts/nuke-coa-dev.sh
```

---

## 10. Troubleshooting

```bash
# See what changed for a stack
make plan-30-services | grep -E '^\s+#|Plan:'

# Rebuild one Lambda zip
touch packages/control-plane/src/*.py && \
  make -C modules/services/namespace/lambdas/control-plane build && \
  make apply-20-namespace

# ECR push failing "no basic auth credentials"
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin \
      $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com

# See a stack's outputs
cd stacks/00-network && terraform output

# See every SSM param published by the stacks
aws ssm get-parameters-by-path --path /coa --recursive --query 'Parameters[].Name' --output table

# Provider transient error on macOS ("failed to read plugin stdout")
xattr -c ~/.terraform.d/plugin-cache/**/*.so 2>/dev/null || true
find stacks -name .terraform -type d -exec rm -rf {} + && make init-all
```

---

## 11. Layer / dependency map

```
00-network ─▶ 10-foundation ─▶ 20-namespace ─▶ 25-ecr ─▶ make build ─┐
                                                                     │
     ┌───────────────────────────────────────────────────────────────┘
     ▼
30-services ─▶ 40-sources ─▶ 50-agentcore ─▶ 55-data-layer ─▶ 60-api-edge ─▶ 70-observability
```

Cross-stack values flow through SSM Parameter Store under `/coa/*`.
Stack 25-ecr publishes each repository under `/coa/ecr/<name>/url`
and `/coa/ecr/<name>/arn`. Stack 50-agentcore publishes the serve
runtime ARN under `/coa/serve/runtime-arn`, consumed by 55-data-layer
and 60-api-edge.
