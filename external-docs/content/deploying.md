# Deploying Context Ontology Accelerator

This guide walks you through deploying Context Ontology Accelerator into your AWS account.

The infrastructure is defined in [Terraform](https://developer.hashicorp.com/terraform)
under `infra-tf/`, split into 10 sequential stacks under `infra-tf/stacks/`
with local state per stack. Cross-stack values flow through SSM Parameter
Store under `/coa/*`. The `Makefile` in `infra-tf/` sequences the apply
end-to-end.

## Prerequisites

| Requirement | Version | Purpose |
|-------------|---------|---------|
| AWS Account | — | Target deployment account |
| AWS CLI v2 | 2.x | Credential management |
| Terraform | 1.14+ | Infrastructure provisioning (`40-sources` uses lifecycle action blocks — 1.14 required) |
| Node.js | 22+ | Web-app build |
| Python | 3.12 | Backend services |
| pnpm | 10+ | TypeScript package management (workspace-aware; npm/yarn will not work) |
| uv | 0.4+ | Python package management |
| Java | 17+ | Smithy code generation |
| Docker | — | Container image builds |
| jq | — | Deploy helper scripts |

## AWS Account Setup

Context Ontology Accelerator deploys into a single AWS account and region. Ensure the deploying principal has `AdministratorAccess` or equivalent permissions for the initial deployment.

### Service Quotas

Two account service quotas can block a deploy. On a fresh or sandbox
account it is worth confirming them up front:

| Quota | Code | Requirement | If too low |
|-------|------|-------------|------------|
| **VPC** (VPCs per Region) | `L-F678F1CE` | Room for one more VPC in the target region (skip when using `vpc_id` to import an existing VPC) | Delete an unused VPC or request an increase — or set `vpc_id` in `shared.tfvars` |
| **Lambda** (Concurrent executions) | `L-B99A9384` | Enough unreserved headroom to reserve the deployment's Lambda concurrency (default 5 × 2 functions = 10) above Lambda's account-wide minimum of 10 | Request an increase, **or** deploy with `lambda_reserved_concurrency = 0` (see [Lambda reserved concurrency](#lambda-reserved-concurrency)) |

Check them with:

```bash
aws ec2 describe-vpcs --query 'length(Vpcs)' --output text
aws lambda get-account-settings \
  --query 'AccountLimit.[ConcurrentExecutions,UnreservedConcurrentExecutions]'
```

New accounts sometimes have the Lambda concurrent-executions quota at the
reduced default of `10`, on which reserving *any* concurrency is rejected.
Raising it (`L-B99A9384`) opens an AWS Support case rather than being granted
immediately, so if you are on a reduced-quota account and want to deploy now,
disable the reservations by setting `lambda_reserved_concurrency = 0` in
`infra-tf/shared.tfvars`.

Several other quotas — OpenSearch Serverless OCUs, Bedrock per-model
invocation limits, Fargate vCPU, ENIs, S3 buckets — can still block a
deploy on a new or sandbox account. See
[Appendix A: Quotas to check](#a3-quotas-to-check-before-deploying) for the
fuller list and why each one matters here.

### Region Selection

Context Ontology Accelerator defaults to `us-east-1`. To deploy to a
different region, set `region` (and `azs`) in `infra-tf/shared.tfvars`:

```hcl
region = "us-west-2"
azs    = ["us-west-2a", "us-west-2b"]
```

Also export `AWS_DEFAULT_REGION` so the AWS CLI and any helper scripts
target the same region as the Terraform stacks:

```bash
export AWS_DEFAULT_REGION=us-west-2
```

### Region Prerequisites

Context Ontology Accelerator **cannot be deployed to every AWS region**. It depends on several
services that are not available everywhere, so the deployable set is the intersection of the regions
where all of them exist.

Regional availability changes continuously as AWS launches services in new regions, so this guide
does not list specific regions — **check each dependency below in your target region before you
deploy**. The fastest way to check all of them at once is the
[AWS Regional Services List](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/),
filtered to your region.

#### Services to verify

Every service in this table must be available in your target region. The first two are the narrowest
constraints in practice — if either is missing, the region is not usable.

| Service | Used for | Check |
|---------|----------|-------|
| **Amazon Bedrock AgentCore Runtime** | Hosts the Serve (query) and MCP server runtimes | [Supported regions](https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/agentcore-regions.html) — note this page lists availability per AgentCore *feature*; you need **Runtime** |
| **Amazon DataZone** / SageMaker Unified Studio | Namespace domain, data-asset catalog | [Endpoints and quotas](https://docs.aws.amazon.com/general/latest/gr/datazone.html) |
| **Amazon Neptune** | Knowledge-graph store | [Endpoints and quotas](https://docs.aws.amazon.com/general/latest/gr/neptune.html) |
| **Amazon OpenSearch Serverless** | Vector search for retrieval | [Endpoints and quotas](https://docs.aws.amazon.com/general/latest/gr/opensearch-service.html) — Serverless is available in fewer regions than managed OpenSearch |
| **Amazon Bedrock** + Guardrails | All LLM and embedding calls; content filtering | [Endpoints and quotas](https://docs.aws.amazon.com/general/latest/gr/bedrock.html) — also check the models themselves (see below) |
| **Amazon Athena** (incl. federated query) | SQL over mapped data sources | [Endpoints and quotas](https://docs.aws.amazon.com/general/latest/gr/athena.html) |

The remaining services the solution uses — Lambda, API Gateway, ECS on Fargate, S3, DynamoDB,
Cognito, CloudFront, WAF, Glue, Step Functions, SSM, CloudWatch — are available in effectively all
commercial regions and are not usually the limiting factor. That list is not exhaustive; for the
complete inventory, including the services that are only called at run time rather than provisioned
by the deploy, see [Appendix A: AWS Service Inventory](#appendix-a-aws-service-inventory-quotas-and-considerations).

!!! warning "GovCloud and China regions are not supported"
    These partitions lack several required dependencies, and the modules assume the `aws` partition in
    ARN construction. Deploying there would need code changes beyond region configuration.

#### Bedrock model availability

Availability of the *service* is not enough — the specific **foundation models must also be
enabled in your region**, and the solution's default model IDs are **US cross-region inference
profiles** (`us.anthropic.…`, `us.cohere.embed-v4:0`) that cannot be invoked from a non-US source
region.

If you deploy outside the US, look each model up in
[Regional availability by models](https://docs.aws.amazon.com/bedrock/latest/userguide/models-region-compatibility.html)
(it shows In-Region / Geo / Global support per region), then replace the default IDs with a profile
that is invocable from your region — a geographic profile (`eu.`, `jp.`, `au.`), a `global.` profile,
or the bare in-region model ID. The models to check:

| Model | Used for |
|-------|----------|
| Claude Sonnet 4.6 | Induction, grounding |
| Claude Haiku 4.5 | Rerank, enrichment, document ingestion |
| Claude Sonnet 5 | Serve query resolution (NL-to-SPARQL, synthesis) |
| Cohere Embed v4 | All embeddings |

Not every model offers every profile type in every region — Cohere Embed v4, for example, publishes
only `us.` and `eu.` geographic profiles. Also
[request model access](https://docs.aws.amazon.com/bedrock/latest/userguide/model-access.html) for
each model in the deploy region, and note that `global.` profiles require
[additional IAM/SCP permissions](https://docs.aws.amazon.com/bedrock/latest/userguide/global-cross-region-inference.html)
beyond what the modules grant by default.

##### Where the model IDs live

Every model ID is a Terraform variable in `infra-tf/variables.tf`, exposed
under `infra-tf/shared.tfvars`. No source edits are required to deploy
outside the US. Set the variables you need before deploying; each falls
back to the built-in default when omitted, so a deployment that configures
none of them behaves exactly as it does today.

| Variable | Sets the model for | Default |
|----------|--------------------|---------|
| `bedrock_llm_model_id` | Serve query LLM (NL-to-SPARQL, synthesis) | `us.anthropic.claude-sonnet-5` |
| `bedrock_embed_model_id` | **All** embeddings — induction, doc-KG-build, metric matching, serve retrieval | `us.cohere.embed-v4:0` |
| `bedrock_embed_dimensions` | Vector dimension for the embedding model above | `1024` |
| `bedrock_induction_llm_model_id` | Ontology induction, grounding rerank, description generation | `us.anthropic.claude-sonnet-5` |
| `bedrock_chat_model_id` | Source enrichment, constraint inference, document-ingestion extraction | `us.anthropic.claude-haiku-4-5-20251001-v1:0` |

Both **geographic inference profiles** (`us.`, `eu.`, `apac.`, `jp.`, `global.`) and **bare in-region model
IDs** (e.g. `cohere.embed-v4:0`) are accepted — bare IDs matter because some models publish geo
profiles for only a subset of regions. The same resolved values also drive the Bedrock IAM grants and
the CloudWatch dashboards' `ModelId` dimensions, so permissions and cost widgets follow your
configuration automatically.

Example `infra-tf/shared.tfvars` for an `ap-northeast-1` deployment (a bare
in-region ID for the embedding model because Cohere Embed v4 publishes no
`jp.` profile):

```hcl
initial_admin_email             = "admin@example.com"
bedrock_llm_model_id            = "global.anthropic.claude-sonnet-5"
bedrock_embed_model_id          = "cohere.embed-v4:0"
bedrock_embed_dimensions        = 1024
bedrock_induction_llm_model_id  = "global.anthropic.claude-sonnet-5"
bedrock_chat_model_id           = "jp.anthropic.claude-haiku-4-5-20251001-v1:0"
```

Not every model publishes a profile for every geography, so check what your region offers before
setting these: `aws bedrock list-inference-profiles` and `aws bedrock list-foundation-models`.

!!! warning "`us.` profiles cannot be invoked outside the US"
    Bedrock rejects a cross-geography inference profile with
    `ValidationException: The provided model identifier is invalid.` Nothing validates model IDs at
    plan time, so a deploy with unusable IDs still reaches `apply-complete` and fails at first
    invocation. Check each model in your target region before deploying.

!!! warning "Changing the embedding model is a data migration"
    All embeddings must use the same model — existing indexes were written with the previous one and
    must be re-ingested, or retrieval degrades silently. `bedrock_embed_dimensions` is baked into the
    OpenSearch index at creation and cannot be changed afterwards. Set both at **initial** deploy.

!!! warning "Only `us-east-1` has been tested"
    `us-east-1` is the default and the only region this solution has been deployed and validated in.
    Other regions that pass the checks above are expected to work, but are unverified — budget time
    for troubleshooting on a first deploy elsewhere.

#### Cross-region and AZ constraints

These apply **no matter which region you deploy to**:

- **`us-east-1` is always involved.** CloudFront-scope WAF WebACLs and CloudFront ACM certificates
  exist only in `us-east-1`, so the edge-WAF resources always use the `aws.us_east_1` provider alias
  in `infra-tf/providers.tf` and `ui_certificate_arn` must be a `us-east-1` certificate. Amazon ECR
  Public is likewise `us-east-1`-only (build-time).
- **Availability Zones can be restricted within a region.** A service being present in a region does
  not mean it is present in every AZ of that region. In `us-east-1`, AgentCore Runtime supports only
  3 of 6 AZs and the OpenSearch Serverless VPC endpoint is offered in a different subset, so
  `infra-tf/stacks/00-network/locals.tf` resolves the intersection at plan time and pins
  the VPC to it. If your region turns out to have similar AZ restrictions, extend
  `agentcore_supported_zone_ids` in that file — otherwise the AgentCore Runtime or the AOSS endpoint
  can fail to create on an unsupported zone.
- **One region per `resource_prefix`.** See the multi-region warning under Configuration below.

## Installation

```bash
git clone <repo-url> && cd ontology-accelerator

# Install pinned tool versions (Python 3.12, Java 17, Node 22, pnpm 10.27.0)
curl https://mise.run | sh
mise install

# make setup runs smithy-generate.sh (make generate) + setup-dev.sh
# (uv sync --all-packages, pnpm install, pre-commit hooks)
make setup
```

`make setup` regenerates Smithy artifacts (`smithy-generated/`) and syncs
Python + Node dependencies. Re-run it after pulling changes that touch
`.smithy` files or `pyproject.toml` / `package.json`.

### Terraform plugin cache (recommended)

Each stack has its own `.terraform/` directory. Without a shared cache,
`terraform init` re-downloads the aws/awscc/time/external providers into
every stack — ~1 GB of duplicated binaries and slow first-inits. Point
Terraform at a shared cache once:

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

## Deploy

The Terraform Makefile (`infra-tf/Makefile`) sequences the full deploy
end-to-end:

```bash
cd infra-tf

# One-time: copy the example tfvars and edit
cp shared.tfvars.example shared.tfvars
$EDITOR shared.tfvars       # at minimum, set initial_admin_email

# Initialize every stack
make init-all

# Deploy everything: foundation → ECR → build → services → observability
make up-all
```

`make up-all` sequences (see `infra-tf/DEPLOY.md` §3d for the full flow):

```
apply-00-network
  → apply-10-foundation
  → build-lambdas                    # 20-namespace needs control-plane.zip
  → apply-20-namespace
  → apply-25-ecr
  → build-images                     # ECR repos now exist for pushes
  → apply-30-services                # metric-service, vkg, ontology
  → apply-40-sources                 # sources ingestion, discovery, KG build
  → apply-50-agentcore               # serve + mcp AgentCore Runtimes
  → apply-55-data-layer              # data-layer Lambda (needs serve ARN)
  → build-web                        # Vite build → packages/web-app/dist
  → apply-60-api-edge                # API Gateway + CloudFront + uploads dist/ to S3
  → apply-70-observability           # CloudWatch alarms
```

Each `apply-*` target is safe to run individually, in order.

### Stacks Deployed

The 10 stacks under `infra-tf/stacks/`:

| Stack | Purpose |
|-------|---------|
| `00-network` | VPC, subnets, security groups, Cloud Map namespace, VPC endpoints |
| `10-foundation` | S3, DynamoDB, OpenSearch Serverless, Neptune, Cognito, Guardrails, WAF |
| `20-namespace` | DataZone + namespace-deletion pipeline |
| `25-ecr` | ECR repositories for all container images |
| `30-services` | Metric service, VKG, ontology engine |
| `40-sources` | Data source ingestion (Glue, JDBC, documents) |
| `50-agentcore` | Serve + MCP AgentCore Runtimes |
| `55-data-layer` | Data Layer Lambda + IAM |
| `60-api-edge` | API Gateway, CloudFront, WAF WebACL, web-app upload |
| `70-observability` | CloudWatch alarms |

Total fresh deploy: **~1.5 hours** for full provisioning of all 10 stacks,
once dependencies are installed and Smithy artifacts are generated.
Neptune and OpenSearch Serverless provisioning, AgentCore Runtime setup,
and cross-stack SSM dependency waits account for most of that time —
individual stacks vary widely and several sub-resources run in parallel,
so a per-stack breakdown understates the real end-to-end wall-clock time.

!!! warning "First-time setup adds significant time"
    The ~1.5 hour figure above is Terraform provisioning time only. On a fresh machine or first-time deploy, budget additional time on top of that for: installing `mise`-managed toolchains, `uv sync`/`pnpm install`, Smithy/Gradle codegen (`make generate` — first run downloads Gradle wrappers, openapi-generator, and builds TypeScript clients from scratch), and Docker image builds. Subsequent deploys after initial setup are faster since dependencies and generated artifacts are cached, though provisioning time for a fresh set of resources remains similar.

### Configuration

`infra-tf/shared.tfvars` (gitignored — copied from `shared.tfvars.example`)
carries every configurable value. Common overrides:

```hcl
# Custom resource prefix (default: coa)
resource_prefix = "myproject"

# Import an existing VPC instead of creating one (BYOVPC)
vpc_id = "vpc-abc123"

# Custom domain for the web app and API — all-or-nothing group
ui_domain_name      = "ontology.example.com"
ui_certificate_arn  = "arn:aws:acm:us-east-1:123456789012:certificate/ui-cert-id"
api_domain_name     = "api.ontology.example.com"
api_certificate_arn = "arn:aws:acm:<region>:123456789012:certificate/api-cert-id"
hosted_zone_id      = "Z0123456789ABCDEFGHIJ"
```

!!! note "Custom domain certificate regions"
    `ui_certificate_arn` must be an ACM certificate in `us-east-1` (CloudFront requirement) regardless of your deploy region. `api_certificate_arn` must be in the same region you're deploying to (API Gateway requirement). The variables are validated at plan time and Terraform fails with a clear error if either is in the wrong region.

!!! warning "Multi-region deployments"
    S3 buckets and IAM roles are globally scoped, not region-isolated. Deploying the same `resource_prefix` + `env` to a second region **will collide** with an existing deployment. Use a distinct `resource_prefix` per region (e.g., `coa-w2` for `us-west-2`) — do not rely on region alone to disambiguate.

#### Database scan enrichment timeout

A database source scan runs an enrichment step (an ECS Fargate task that calls Bedrock once per discovered table). It is bounded by a deadline; when the deadline is hit the scan fails cleanly to `SCAN_FAILED` so the source can be deleted or re-scanned, rather than being stranded mid-scan. The default deadline is **120 minutes**, sized to comfortably cover a large source (roughly 2,000 tables at ~30–35 s per table with ten tables enriched in parallel).

Raise it only if you are onboarding a source large enough to exceed that — a scan that fails on the deadline reports `SCAN_FAILED`, and this is the knob to give it more time. In `infra-tf/shared.tfvars`:

```hcl
db_scan_enrichment_timeout_minutes = 180
```

The value is minutes and must be a positive number; Terraform fails plan otherwise. The Step Functions state-machine ceiling is derived automatically as this value plus two minutes, so the per-task deadline always trips first and routes the source to `SCAN_FAILED`.

#### Lambda reserved concurrency

Two Lambdas — the VKG reloader and the document preprocessor — reserve concurrent executions (default **5** each) to bound their blast radius. On an account whose **Lambda concurrent-executions quota** (`L-B99A9384`) is at the reduced default of **10** — which AWS applies to some new accounts — reserving *any* concurrency is rejected, because it would drop unreserved capacity below Lambda's account-wide minimum of 10. The deploy runs and then fails on `30-services` (and `40-sources` after it) with:

```
Specified ReservedConcurrentExecutions for function decreases account's
UnreservedConcurrentExecution below its minimum value of [10].
```

Raising the quota via `request-service-quota-increase` on `L-B99A9384` opens an AWS Support case rather than being granted immediately, so the fast unblock is to deploy without the reservations. In `infra-tf/shared.tfvars`:

```hcl
lambda_reserved_concurrency = 0
```

The value must be a non-negative integer. `0` omits the reservation entirely — the functions then draw from the shared unreserved pool with no dedicated guarantee or cap, which is fine for a single-tenant evaluation.

### Internal Environment Variables

These are set by the Terraform modules and are not user-configurable:

| Variable | Set By | Purpose |
|----------|--------|---------|
| `SCL_MCP_MODE` | `modules/services/mcp/main.tf` | Switches the container entrypoint between Context Manager (default) and MCP Server. When set to `"true"`, the container starts in MCP mode. |
| `BULK_REVIEW_PAGE_BUDGET` | `worker.py` default | Per-invocation table budget for the bulk-review worker (default `1000`); when a source has more tables, the worker processes one page, re-enqueues a continuation, and resumes across chained invocations rather than silently capping. |
| `BULK_REVIEW_WALL_CLOCK_BUDGET_S` | `worker.py` default | Per-invocation wall-clock budget in seconds (default `240`), a second guard under the 5-minute Lambda timeout that stops the worker after the current search page and continues in a fresh invocation when neared. |
| `REVIEW_QUEUE_URL` | `modules/services/sources/sqs.tf` | SQS review-queue URL the bulk-review worker re-enqueues page continuations to, wiring its own self-continuation. |

### API Request Limits and Rate Limiting

Context Ontology Accelerator throttles inbound API traffic at three layers. All limits are **soft** —
they ship with conservative defaults and can be tuned per deployment. Defaults
live in the module variables under `infra-tf/modules/services/api/` and
`infra-tf/modules/foundation/edge-waf/`.

| Layer | Default | Applies to |
|-------|---------|------------|
| WAF per-IP rate limit | **2000 requests / 5 min per source IP** (block) | Every request, at the edge (CloudFront) and API (before auth) |
| API Gateway stage-wide throttle | **50 rps / 100 burst** | All API methods |
| API Gateway per-operation throttle | **5 rps / 10 burst** | Expensive, job-launching operations only |

**Expensive operations** (the routes that receive the tighter 5 rps / 10 burst
throttle, because each request launches a long-running job or a heavy graph
write):

- `POST /namespaces/{namespaceId}/induce` — ontology induction
- `POST /namespaces/{namespaceId}/sources/{sourceId}/rescan` — source rescan
- `POST /namespaces/{namespaceId}/import-osi` — metric OSI import
- `POST /namespaces/{namespaceId}/proposals/{proposalId}/infer-constraints`
- `POST /namespaces/{namespaceId}/proposals/{proposalId}/validate`
- `POST /namespaces/{namespaceId}/proposals/{proposalId}/compile-constraints`
- `POST /namespaces/{namespaceId}/proposals/{proposalId}/accept`

**Overriding the limits.** All three are Terraform variables — set them in
`shared.tfvars` and re-apply the affected stack:

```hcl
# stack 60-api-edge
api_throttle_rate_limit             = 100
api_throttle_burst_limit            = 200
api_expensive_throttle_rate_limit   = 10
api_expensive_throttle_burst_limit  = 20

# stack 10-foundation (edge WAF) and 60-api-edge (regional WAF)
waf_rate_limit_per_5min = 5000
```

To bring an entirely pre-built WebACL instead of the auto-created one, set
`api_web_acl_arn` (REGIONAL, API stage) or `cloudfront_web_acl_arn`
(CloudFront edge) to the ARN of your existing WebACL; the built-in WebACL
and its rate rule are then skipped entirely for that surface.

**When to tune for production.** The defaults suit a modest authenticated-user
population. Raise the stage-wide and per-operation throttles if legitimate
concurrent usage triggers 429s; raise the WAF limit if a shared-egress client
(corporate NAT, VPN) legitimately exceeds 2000 req/5min from one IP.

**Monitoring.** Throttling is visible in CloudWatch:

- API Gateway `4XXError` metric — includes HTTP **429 Too Many Requests**
  returned when a caller exceeds a throttle (the burst bucket is empty).
- WAF `BlockedRequests` metric, rule `{prefix}-{env}-{api|cloudfront}-waf-rate-limit-per-ip`
  — counts IPs blocked by the rate-based rule (the API stage WebACL uses the
  `api` prefix, the CloudFront edge WebACL uses `cloudfront`).

A client receiving **HTTP 429** should back off and retry with jitter; the limit
is per-second steady-state with a short burst allowance, so a brief pause clears
it.

## Post-Deployment

### 1. Create Your First User

By default (`idp_type = "COGNITO"`, no `oidc_settings` configured), the deployment
creates a Cognito User Pool. Add users via the AWS Console or CLI:

```bash
aws cognito-idp admin-create-user \
  --user-pool-id <POOL_ID> \
  --username user@example.com \
  --user-attributes Name=email,Value=user@example.com Name=email_verified,Value=true
```

The User Pool ID is in `stacks/10-foundation`'s outputs and at SSM
`/<prefix>/userpool-id`.

!!! note "Using your own identity provider instead"
    Context Ontology Accelerator can use an external OIDC-compliant IdP (Okta, Azure AD,
    Auth0, Keycloak, etc.) instead of Cognito — set `idp_type = "OIDC"` with
    `oidc_settings` in `infra-tf/shared.tfvars` **before** running
    `make up-all` (this must be configured pre-deploy; switching IdP types
    afterward requires a re-apply of `10-foundation` and `60-api-edge`). See the
    [Authentication Setup Guide](authentication-setup.md) for the full config
    reference and a step-by-step Okta walkthrough. In OIDC mode, the
    `auth-idp` module does **not** create a Cognito User Pool at all — the
    commands above won't apply. Instead, create/manage users directly in your
    IdP; access is controlled entirely by [grants](role-permission-management.md)
    against the user's email or IdP group.

### 2. Access the Web App

The web app URL is in `stacks/60-api-edge`'s outputs (`cloudfront_distribution_domain_name`):

```bash
cd infra-tf/stacks/60-api-edge && terraform output -raw cloudfront_distribution_domain_name
```

Sign in with the Cognito user you created (or your external IdP's credentials, if using OIDC mode).

### 3. Grant Platform Admin

To give a user full access, grant the `platform-admin` role via the API or web app Permissions page.

## Guardrail Observability

Every Bedrock call routed through a guardrail — the kg-build content screener,
the enrichment and ontology-shape inference tasks, and the serve NL→SPARQL and
retrieval paths — emits a CloudWatch metric and a structured log line on **both**
the allow and the block outcome. This lets operators watch the block rate and
the latency the guardrail adds without any content or PII leaving the request.

### CloudWatch Metrics

All three metrics live in the **`COA/Guardrails`** namespace:

| Metric | Unit | Dimensions | Meaning |
|--------|------|------------|---------|
| `GuardrailInvocations` | Count | `Component`, `Decision` | One per guarded call. `Decision` is `ALLOW` or `BLOCK`. |
| `GuardrailBlocked` | Count | `Component` | Emitted (value `1`) only when the guardrail intervened with a block. |
| `GuardrailLatency` | Milliseconds | `Component` | Wall-clock time the guarded Bedrock call took. |

`Component` is one of `kg-build`, `enrichment`, `ontology-shapes`,
`nl-to-sparql`, or `serve-retrieval`.

**Block rate is not a stored metric** — compute it in a CloudWatch math
expression so there is a single source of truth:

```
100 * (GuardrailBlocked / GuardrailInvocations)
```

(Sum `GuardrailInvocations` across both `Decision` values, or drop the
`Decision` dimension in the metric selector, before dividing.)

### Viewing the metrics

List the metrics and read the last hour of a component's invocations:

```bash
# What's being published
aws cloudwatch list-metrics --namespace COA/Guardrails

# ALLOW+BLOCK invocations for the NL→SPARQL path, 5-min buckets
aws cloudwatch get-metric-statistics \
  --namespace COA/Guardrails --metric-name GuardrailInvocations \
  --dimensions Name=Component,Value=nl-to-sparql \
  --start-time "$(date -u -d '1 hour ago' +%FT%TZ)" \
  --end-time "$(date -u +%FT%TZ)" \
  --period 300 --statistics Sum
```

### Dashboard block-rate widget

A metric-math widget that graphs the per-component block-rate percentage:

```json
{
  "type": "metric",
  "properties": {
    "title": "Guardrail block rate (%)",
    "region": "us-west-2",
    "metrics": [
      [ "COA/Guardrails", "GuardrailBlocked", "Component", "nl-to-sparql", { "id": "b", "visible": false } ],
      [ "COA/Guardrails", "GuardrailInvocations", "Component", "nl-to-sparql", { "id": "i", "visible": false } ],
      [ { "expression": "100 * b / i", "label": "nl-to-sparql", "id": "rate" } ]
    ],
    "stat": "Sum",
    "period": 300
  }
}
```

### Recommended alarm

Guardrails are a security control, so a sustained spike in the block rate is
worth paging on — it signals either an attack (prompt injection, PII probing) or
a misconfigured upstream. Alarm on the block-rate math expression:

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name coa-guardrail-block-rate-high \
  --alarm-description "Guardrail block rate exceeded 20% for 15 minutes" \
  --comparison-operator GreaterThanThreshold --threshold 20 \
  --evaluation-periods 3 --datapoints-to-alarm 3 \
  --metrics '[
    {"Id":"rate","Expression":"100 * b / i","Label":"block-rate","ReturnData":true},
    {"Id":"b","MetricStat":{"Metric":{"Namespace":"COA/Guardrails","MetricName":"GuardrailBlocked"},"Period":300,"Stat":"Sum"},"ReturnData":false},
    {"Id":"i","MetricStat":{"Metric":{"Namespace":"COA/Guardrails","MetricName":"GuardrailInvocations"},"Period":300,"Stat":"Sum"},"ReturnData":false}
  ]'
```

A high `GuardrailLatency` p90/p99 (e.g. above a few hundred ms) is also worth an
alarm — it surfaces guardrail evaluation slowing down the request path.

### Structured decision logs

Alongside the metrics, each decision writes one JSON log line
(`event: "guardrail_decision"`) to the component's CloudWatch Logs group:

| Field | Example | Meaning |
|-------|---------|---------|
| `component` | `nl-to-sparql` | Which decision site emitted the line. |
| `decision` | `ALLOW` / `BLOCK` | The guardrail outcome. |
| `filter_type` | `CONTENT` / `PII` / `TOPIC` / `NONE` | Which policy family fired (most-severe wins; `NONE` on an allow). |
| `latency_ms` | `142.3` | Wall-clock of the guarded call. |

The log **never** carries the matched content or the PII value — only the
policy *category* — so these lines are safe to retain and query. Find recent
blocks across a log group with CloudWatch Logs Insights:

```
fields @timestamp, component, filter_type, latency_ms
| filter event = "guardrail_decision" and decision = "BLOCK"
| sort @timestamp desc
```

> **Note on the region.** Metrics are published in the deployed region (the ECS
> tasks resolve it from `BEDROCK_REGION`/`LLM_REGION`, not `AWS_REGION`). If a
> dashboard is empty, confirm you are looking at the region the stack deployed
> to, not `us-east-1`.

## Updating

To deploy updates after pulling new code:

```bash
git pull
cd infra-tf
make up-all      # rebuilds artifacts, re-applies affected stacks
```

Terraform's plan/apply is incremental — only the resources that actually
changed are updated. To re-apply a single stack in isolation:

```bash
cd infra-tf
make apply-30-services
```

## Tearing Down

The reverse-order teardown mirrors the deploy sequence. `make down-all`
runs the full sequence:

```bash
cd infra-tf
make down-all
```

Or invoke stacks individually in reverse:

```bash
cd infra-tf
make destroy-70-observability
make destroy-60-api-edge
make destroy-55-data-layer
make destroy-50-agentcore
make destroy-40-sources
make destroy-30-services
make destroy-25-ecr
# then clean DataZone manually via the console (see below), then:
make destroy-20-namespace
make destroy-10-foundation
make destroy-00-network
```

!!! warning "DataZone requires manual cleanup"
    The namespace module marks DataZone resources `lifecycle { prevent_destroy = true }` because DataZone requires specific pre-delete state (FormType DISABLED, project ownership cascades) that Terraform cannot reproduce reliably. Delete the domain and its projects manually via the AWS console (or `datazone delete-domain --skip-deletion-check`) before running `destroy-20-namespace`.

!!! warning
    This deletes all resources including databases and stored data. Neptune and OpenSearch data is not recoverable after deletion.

### Full reset for dev

For a nuclear reset that clears every `coa-dev-*` resource plus every
stack's local state, use `infra-tf/scripts/nuke-coa-dev.sh` — see
`infra-tf/DEPLOY.md` §9 for details.

## Troubleshooting

### Terraform plan/apply hangs on provider download

The stacks each carry their own `.terraform/` cache, so a fresh clone
downloads providers per-stack (~1 GB each). Set up the Terraform plugin
cache once — see [Terraform plugin cache](#terraform-plugin-cache-recommended)
above.

### `Domain name already exists under this account (DataZone, 409)`

**Symptom:** `20-namespace` fails to apply the DataZone domain because a
prior apply left one behind after a failed rollback, or a manual `terraform
destroy` didn't reach it.

**Cause:** DataZone resources are `prevent_destroy = true`, so Terraform
cannot clear them itself. A partial teardown or CFN-migration remnant can
leave an orphaned domain that a fresh apply cannot recreate under the same
name.

**Fix:** force-delete the leftover domain and retry:

```bash
DOMAIN_ID=$(aws datazone list-domains \
  --query "items[?name=='<PREFIX>-<ENV>-smus-catalog'].id" --output text)
aws datazone delete-domain --identifier "$DOMAIN_ID" --skip-deletion-check
# wait for status DELETED, then retry
cd infra-tf && make apply-20-namespace
```

### AgentCore ENI wait can take hours after runtime deletion

**Symptom:** the `50-agentcore` stack fails to delete a security group with
`has a dependent object` (`DependencyViolation`) even after the runtime is
gone.

**Cause:** AgentCore Runtime provisions VPC network interfaces (ENIs)
directly, outside Terraform. Runtime deletion doesn't synchronously release
them — in practice this has been observed to take **several hours, and
sometimes days**, not the few minutes originally expected. Terraform has no
visibility into these ENIs and tries to delete the security group
immediately, before they're gone.

**Fix:** there isn't a fast one. Re-run the destroy later:

```bash
cd infra-tf && make destroy-50-agentcore
```

Do not attempt to manually detach or delete the ENIs yourself — they're
AWS-managed and manual intervention doesn't speed up the release.

### Provider transient error on macOS (`failed to read plugin stdout`)

```bash
xattr -c ~/.terraform.d/plugin-cache/**/*.so 2>/dev/null || true
find infra-tf/stacks -name .terraform -type d -exec rm -rf {} +
cd infra-tf && make init-all
```

### UI shows stale API endpoint after `60-api-edge` changes

The web-app upload is done, but CloudFront caches `runtime-config.json` and
`index.html` for up to 24h. Force a cache invalidation:

```bash
CF_ID=$(cd infra-tf/stacks/60-api-edge && terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id "$CF_ID" --paths '/*'
```

### API Gateway has zero authorizers / every route returns 401

The OpenAPI import silently drops a custom-authorizer securityScheme when
`x-amazon-apigateway-authtype: custom` is missing.
`infra-tf/modules/services/api/locals.tf` preserves it in the
`enriched_spec` transformation; if you touch that transformation, verify:

```bash
aws apigateway get-authorizers \
  --rest-api-id $(cd infra-tf/stacks/60-api-edge && terraform output -raw api_id) \
  --region us-east-1
```

## Appendix A — AWS Service Inventory, Quotas, and Considerations

This appendix consolidates every AWS service the solution touches, the account
quotas worth checking before a deploy, and the non-obvious considerations behind
specific resource choices. It is scoped to the **single-account, single-region
evaluation deployment** this guide describes.

It complements rather than repeats the sections above — see
[Service Quotas](#service-quotas) for the two quotas worth confirming, [Region
Prerequisites](#region-prerequisites) for regional availability, and [API
Request Limits](#api-request-limits-and-rate-limiting) for inbound throttling.

### A.1 Services provisioned by Terraform

Every service below is created by `make up-all`. "Owning module" points at
the Terraform module under `infra-tf/modules/`. Substitute your own
`resource_prefix` for `coa` in resource names.

| Service | Used for | Owning module(s) |
|---------|----------|-----------------|
| **Amazon VPC** (EC2) | Private networking for all compute; Lambdas and tasks are VPC-bound | `foundation/network` (+ every service module) |
| **AWS Lambda** | API handlers, workers, custom resources, ontology reload | `services/api`, `services/data-layer`, `services/sources`, `services/ontology`, `services/vkg`, `services/namespace`, `services/metric-service`, `services/serve` |
| **Amazon ECS on Fargate** | Long-running containers: enrichment, doc ingestion, Ontop VKG | `services/sources`, `services/ontology`, `services/vkg` |
| **Amazon Neptune** | Knowledge-graph store (RDF/SPARQL) | `foundation/storage` |
| **Amazon OpenSearch Serverless** | Vector search for retrieval and grounding | `foundation/storage` (collection); every service module (access policies) |
| **Amazon DynamoDB** | Job/proposal state, roles, grants, Cedar policies, sessions | `foundation/authnz`, `services/api`, `services/sources`, `services/ontology`, `services/namespace`, `services/metric-service`, `services/serve`, `services/mcp` |
| **Amazon S3** | Ontology artifacts, staged documents, web assets, access logs | `foundation/storage`, `services/sources`, `services/ontology`, `services/vkg`, `services/metric-service`, `foundation/web` |
| **Amazon Bedrock** | All LLM and embedding inference | Called by `services/ontology`, `services/sources`, `services/serve`, `services/mcp` |
| **Bedrock Guardrails** | Content/PII filtering on guarded calls | `foundation/guardrail` |
| **Bedrock AgentCore Runtime** | Hosts the Serve and MCP runtimes | `services/serve`, `services/mcp` |
| **Amazon DataZone** / SageMaker Unified Studio | Namespace domain, projects, data-asset catalog | `services/namespace` |
| **Amazon API Gateway** | REST API surface, authorizer, per-route throttles | `services/api` |
| **Amazon Cognito** | Default identity provider (skipped in OIDC mode) | `foundation/auth-idp` |
| **AWS WAF** (WAFv2) | Per-IP rate limiting at the edge and API stage | `services/api`, `foundation/edge-waf` |
| **Amazon CloudFront** | Web-app CDN and TLS termination | `foundation/web` |
| **AWS Step Functions** | Source-scan orchestration, namespace-deletion pipeline | `services/sources`, `services/namespace` |
| **Amazon SQS** | Review queue, bulk-review worker continuations, async work | `services/api`, `services/sources`, `services/metric-service` |
| **Amazon EventBridge** | Scan/ingest event routing and scheduled rules | `services/sources`, `services/ontology`, `services/vkg` |
| **AWS Cloud Map** (servicediscovery) | Per-namespace VKG service discovery | `foundation/network`, `services/ontology`, `services/vkg` |
| **Amazon ECR** | Container images for Fargate tasks and AgentCore | `services/sources`; image consumers in `services/serve`, `services/mcp` |
| **AWS Systems Manager** (SSM) | Cross-stack parameters and deploy config | Every stack |
| **Amazon CloudWatch** + Logs | Metrics, log groups, dashboards | `services/api`, `services/ontology`, `services/vkg`, `services/sources`, `observability` |
| **AWS IAM** | Task/function roles, least-privilege grants | Every module |
| **AWS Certificate Manager** | TLS certs for custom API/UI domains (optional) | `services/api`, `foundation/web` |
| **Amazon Route 53** | DNS records for custom domains (optional) | `services/api`, `foundation/web` |

### A.2 Services called at runtime but not provisioned

These are invoked by application code via the AWS SDK. They are **not created by
the deploy**, so they either already exist in your account, are created
per-source when you onboard data, or must be provisioned separately. This is the
group most easily missed when scoping IAM permissions or regional availability.

| Service | Used for | Called from |
|---------|----------|-------------|
| **Amazon Athena** | SQL over mapped data sources; table sampling; namespace cleanup | `packages/context-manager/.../clients/athena.py`, `packages/sources/.../database/connectors/athena_sampler.py`, `packages/control-plane/.../namespace/` |
| **AWS Glue** | Data Catalog reads; JDBC connection provisioning for scans | `packages/sources/.../database/connectors/glue_catalog.py`, `glue_connection_provisioner.py` |
| **AWS Lake Formation** | Permission grants when provisioning Glue connections | `packages/sources/.../database/connectors/glue_connection_provisioner.py` |
| **Amazon Textract** | OCR for scanned/PDF documents during preprocessing | `packages/sources/.../documents/preprocessing/handler.py` |
| **Amazon Redshift Data API** | Querying Redshift-backed sources | `packages/context-manager/.../clients/redshift_data.py` |
| **AWS Secrets Manager** | Data-source credentials (e.g. JDBC) | `packages/sources`, `packages/context-manager` |
| **AWS STS** | Role assumption and caller identity across services | Widely used (~10 modules) |

### A.3 Quotas to check before deploying

Confirm the two quotas from [Service Quotas](#service-quotas) up front. The
rest are listed because they are plausible blockers on a **new or sandbox
account**, where reduced default quotas are common. Confirm the ones
relevant to your usage rather than requesting increases for all of them.

Quota codes and the AWS defaults below were read from
`service-quotas list-aws-default-service-quotas`. Defaults change over time and
your account may already differ — treat them as a starting point and check your
own applied values with the commands that follow.

| Service | Quota (code) | AWS default | Why it matters here |
|---------|--------------|-------------|---------------------|
| **VPC** | VPCs per Region (`L-F678F1CE`) | 5 | Deploy creates one VPC unless `vpc_id` is set. See [Service Quotas](#service-quotas) |
| **Lambda** | Concurrent executions (`L-B99A9384`) | 1,000 (10 on some new accounts) | Two functions reserve concurrency (default 5 each). See [Lambda reserved concurrency](#lambda-reserved-concurrency) |
| **ECS / Fargate** | Fargate On-Demand vCPU resource count (`L-3032A538`) | **6** | **The tightest fit here.** Tasks are 2 vCPU / 8 GB and 4 vCPU / 16 GB, and VKG runs one service **per namespace** — so a single enrichment task plus two namespaces' VKG services can exhaust the default |
| **OpenSearch Serverless** | Indexing max OCU (`L-50FA809B`), search max OCU (`L-4E98D4EB`) | 10 each | The collection runs with standby replicas enabled, which roughly doubles OCU consumption — see [A.4](#a4-considerations) |
| **Amazon Bedrock** | Per-model invocation TPM / RPM — one quota per model **per inference profile** (e.g. `L-CCA5DF70`, cross-region RPM for Claude Haiku 4.5) | Varies widely by model (hundreds of thousands to hundreds of millions of tokens/min) | Induction throughput is bounded by model tokens-per-minute far more often than by compute; a large scan can hit it. Look up the four models in [Bedrock model availability](#bedrock-model-availability) for the profile you actually invoke |
| **Amazon Athena** | Active DML queries (`L-FC5F6546`) | 200 | Concurrent structured queries at serve time share this pool |
| **Amazon Neptune** | DB instances (`L-368A3E00`) | 40 | Deploy creates one instance. The more likely constraint is not the count but whether the `db.r8g.large` Graviton class is offered in your region and AZ |
| **Amazon Textract** | `DetectDocumentText` TPS (`L-75788A8B`) | 25 | Only relevant if ingesting scanned documents at volume |

Quotas that are **not** worth checking, having confirmed the headroom: the deploy
creates ~10 layered stacks against Terraform's own limits, about 11 S3 buckets
against a far higher bucket limit, and consumes ENIs against a default of
5,000 per Region (`L-DF5E4CA3`). A single NAT gateway means one Elastic IP.
AgentCore's slow ENI release after teardown is a real problem, but it is a
*timing* issue rather than a quota one — see
[AgentCore ENI wait](#agentcore-eni-wait-can-take-hours-after-runtime-deletion).

Check a specific quota's default and your account's applied value with:

```bash
# Find the code for a quota (search by name within a service)
aws service-quotas list-aws-default-service-quotas --service-code fargate \
  --query "Quotas[?contains(QuotaName, 'vCPU')].[QuotaCode,QuotaName,Value]" --output table

# Your account's applied value, which includes any increases already granted
aws service-quotas get-service-quota --service-code fargate --quota-code L-3032A538 \
  --query 'Quota.[QuotaName,Value]' --output text
```

!!! warning "Quota increases are not always immediate"
    Some increases are auto-approved; others (notably Lambda concurrent
    executions, `L-B99A9384`) open an AWS Support case. If you are on a
    reduced-quota account and need to deploy today, prefer the documented
    workarounds — e.g. `lambda_reserved_concurrency = 0` — over waiting on
    an increase.

### A.4 Considerations

Non-obvious choices and consequences worth knowing before you deploy. Ordered
roughly by how likely each is to surprise you.

**Bedrock model quotas are the real throughput ceiling.** Induction and
enrichment are LLM-bound, not CPU-bound. A database scan calls Bedrock once per
discovered table, which is why the enrichment step has a 120-minute deadline
(see [Database scan enrichment timeout](#database-scan-enrichment-timeout)). If
scans fail on that deadline against a large source, check per-model TPM
throttling before raising the timeout — more time does not help if you are being
throttled.

**OpenSearch Serverless has a cost and OCU floor.** The collection is
`VECTORSEARCH` type inside a `NEXTGEN` collection group, which requires
`standbyReplicas: ENABLED` (see `infra-tf/modules/foundation/storage/opensearch.tf`).
Standby replicas roughly double OCU consumption versus a single-AZ
configuration, and Serverless bills a minimum OCU allocation whether or not you
are querying — so an idle evaluation deployment still accrues cost here. This is
a durability/availability requirement of the collection group type, not a tunable
knob.

**Neptune runs a single provisioned instance, not Serverless.** One
`db.r8g.large` primary with no read replica, IAM (SigV4) auth, encryption at
rest, and 7-day backups. Deletion protection is enabled **only** when
`env = "prod"`. Two consequences for a `dev` deploy: there is no availability
guarantee from a second instance, and the cluster is deletable — so
`make destroy-00-network` (via `make down-all`) will remove the graph and its
data irreversibly.

**Neptune and OpenSearch dominate deploy time.** They, plus AgentCore Runtime
setup and cross-stack SSM waits, are why a fresh deploy takes ~1.5 hours. A
deploy that looks stuck is usually waiting on one of them — check
`aws cloudformation list-stacks` or the applicable module's log output before
intervening.

**Teardown is not symmetric with deploy.** AgentCore Runtime provisions ENIs
outside Terraform and can hold them for hours to days after runtime deletion,
blocking security-group deletion. VKG creates ECS services outside Terraform
(one per namespace, via the ontology-reload Lambda), and DataZone domains
need a force-delete. Budget for teardown taking longer than deploy, and see
[Tearing Down](#tearing-down).

**Per-namespace resources scale with tenant count.** VKG runs one ECS service
per namespace, created by the ontology-reload Lambda rather than Terraform.
Fargate task count, ENIs, and Cloud Map registrations therefore grow as
namespaces are added — relevant to the Fargate vCPU and ENI quotas in
[A.3](#a3-quotas-to-check-before-deploying), and the reason those quotas are
worth checking against your expected namespace count rather than against a
single-namespace evaluation.

**Runtime-only services expand the IAM and regional surface.** The services in
[A.2](#a2-services-called-at-runtime-but-not-provisioned) — Athena, Glue, Lake
Formation, Textract, Redshift Data API, Secrets Manager — are not created by the
deploy but are called by it. Athena and Glue are exercised by any structured
source; Textract only by scanned-document ingestion; Redshift Data API only by
Redshift-backed sources. If you deploy to a region missing one of the services
you actually use, the failure appears at feature-use time rather than at deploy
time.

**`us-east-1` is always in the picture.** Even for a non-`us-east-1`
deployment: the CloudFront-scope WAF WebACL and the UI ACM certificate must
live in `us-east-1`, and ECR Public (build-time image pulls) is
`us-east-1`-only. See
[Cross-region and AZ constraints](#cross-region-and-az-constraints).

**Availability Zones matter, not just regions.** AgentCore Runtime and the
OpenSearch Serverless VPC endpoint support different AZ subsets within
`us-east-1`, so `stacks/00-network/locals.tf` pins the VPC to their
intersection. A service being listed as available in your region does not mean
it is available in every AZ of it.
