# Upstream Sync — context-ontology-accelerator (COA) → downstream Terraform fork

## Overview

This SOP brings the downstream branch up to date with an upstream COA
**release tag** (e.g. `v0.3.3`) published on the official AWS repository —
never with upstream `main` or any other moving branch, and never with a
fork or personal clone of upstream.
The two trees have diverged structurally: upstream still ships its
infrastructure as AWS CDK under `infra/`, while this branch removed that tree
entirely and replaced it with Terraform under `infra-tf/`
(stacks) and `infra-tf/modules/` (modules). A sync therefore has three
jobs that pull against each other: take every upstream app-code fix, never
re-introduce CDK, and never clobber the downstream's own intentional edits.

The sync is **one-way**. Changes flow from upstream into this branch; nothing
is ever contributed back. That is why a plain `git merge` is not an option —
it surfaces hundreds of "added by them / deleted by us" conflicts on the CDK
tree and is unreviewable. Instead the SOP classifies every differing file
deterministically, bulk-imports the files only upstream touched, hand-merges
the files both sides touched, and separately *translates* the intent of each
upstream CDK change into its Terraform equivalent, because the CDK files
themselves are always skipped.

The SOP is written for either a human operator or an agent. RFC 2119
keywords (**MUST**, **SHOULD**, **MAY**, **MUST NOT**, **SHOULD NOT**) carry
their standard meanings. Every "verify" or "confirm" in this document means
*run a deterministic command and check its exit code or output* — never
"looks right on inspection." Silent failures (a misclassified file, a
checkout that didn't stage, a test that would fail in CI) are the main risk
this SOP exists to prevent.

Appendices A–D are snapshots taken at the end of the last sync. They go stale
the moment a module changes and MUST be re-verified against source before
being treated as fact (see each appendix's own note).

Syncing from a tag rather than a branch is deliberate. A release tag is
immutable, has been through upstream's own release checks, and gives every
sync an exact, citable endpoint: the range under review is always
`<previous synced tag>..<new tag>`, so two people running the SOP against the
same tag get byte-identical classification output. Unreleased commits on
upstream `main` are never pulled in, even when they look like the fix you
need — wait for the release that contains them.

**Reference executions.** This SOP was refined through real syncs on a
downstream Terraform fork of COA. Illustrative numbers in callouts below
(classification counts, lockfile diff sizes, pnpm versions, raw/owned
DRIFT counts) come from those executions and will differ for your
downstream — treat them as expected *shape*, not canonical values.

## Parameters

- **upstream_url** (fixed: `https://github.com/aws/context-ontology-accelerator.git`): the official AWS COA
  repository. Not a fork, not a teammate's clone. Releases are listed at
  `https://github.com/aws/context-ontology-accelerator/tags`
- **upstream_remote** (optional, default: `aws-upstream`): local name for
  that remote
- **release_tag** (required): the upstream release to sync to, e.g.
  `v0.3.3`. Exported as `$UPSTREAM_TAG` and used as the upstream ref in every
  command below
- **previous_tag** (optional, default: discovered — see constraints): the
  upstream release this branch was last synced to. Exported as `$PREV_TAG`
  and used as `$BASE`
- **target_branch** (optional, default: current branch): the downstream
  branch receiving the sync (e.g. `feat/your-downstream-branch`)
- **sync_dir** (optional, default: `/tmp/upstream-sync`): scratch directory
  for classification files, snapshots, commit-message drafts, and a
  throwaway Python venv. Referenced as `$SYNC_DIR` below
- **plan_version** (required when step 3 runs): integer `<N>` for the port
  plan file `CDK_TO_TF_SYNC_PLAN_v<N>.md`

**Constraints for parameter acquisition (preconditions):**
- You MUST confirm the working tree is clean: `git status --short` shows no
  staged or modified entries. Untracked files are acceptable but SHOULD be
  reviewed — they may be leftover work
- You MUST have the official AWS repository configured as a fetch-only
  remote, and fetch its tags from it:
  ```bash
  git remote get-url aws-upstream 2>/dev/null \
    || git remote add aws-upstream https://github.com/aws/context-ontology-accelerator.git
  git remote get-url aws-upstream            # MUST print https://github.com/aws/context-ontology-accelerator.git
  git remote set-url --push aws-upstream DISABLED   # one-way: never push upstream
  git fetch aws-upstream --tags -q
  git ls-remote --tags aws-upstream | grep -E 'refs/tags/v[0-9]' | tail -5
  ```
  You MUST NOT sync from a remote that points at a fork or local clone
  (e.g. an existing `coa-upstream` remote pointing at
  `../context-ontology-accelerator`) — those may carry unreleased or
  downstream-modified commits and typically have no release tags at all
- You MUST confirm the release tag exists and resolves to a commit:
  ```bash
  export UPSTREAM_TAG=<release_tag>
  git rev-parse --verify "$UPSTREAM_TAG^{commit}"
  ```
  If it fails, STOP (see Troubleshooting). You MUST NOT fall back to a
  branch tip
- You MUST confirm `git branch --show-current` returns `target_branch`
- You MUST determine `$PREV_TAG` and set `BASE` to it. Every drift
  decision below is relative to `$BASE`:
  ```bash
  # prior sync commits carry an Upstream-Release trailer (step 7)
  PREV_TAG=$(git log --format='%(trailers:key=Upstream-Release,valueonly)' HEAD \
               | grep -m1 -E '^v[0-9]')
  export PREV_TAG BASE="$PREV_TAG"
  git rev-parse --verify "$BASE^{commit}"
  ```
  `$BASE` MUST be the previous synced tag, **not** `git merge-base HEAD
  "$UPSTREAM_TAG"`. Syncs import files selectively and never merge upstream
  history, so the merge base never advances past the original fork point —
  using it makes every file any prior sync touched look like DRIFT
- If no `Upstream-Release` trailer exists yet (i.e. the first tag-based
  sync on this downstream), you MUST set `previous_tag` explicitly and
  confirm it with the user before step 1. Only if the previous release
  genuinely cannot be identified MAY you fall back to the merge base, and
  you MUST then expect the raw-vs-owned DRIFT inflation described in step 2
- You MUST confirm the new release is strictly newer:
  `git merge-base --is-ancestor "$PREV_TAG" "$UPSTREAM_TAG"` exits 0 and the
  two tags resolve to different commits
- You MUST record the starting point: `export SYNC_START=$(git rev-parse HEAD)`
- You MUST confirm the toolchain is present: `git`, `terraform` (matching the
  version pinned in each stack's `terraform.tf`), Python 3.12 with
  `pip`/`pytest`, Node 22+, Java 17+ and Gradle (Smithy codegen), and `jq`.
  If any is missing, STOP and install it — do not skip the steps that need it
- You MUST create `$SYNC_DIR` if it doesn't exist and confirm it is writable
- You MUST announce `$PREV_TAG`, `$UPSTREAM_TAG`, and the commit SHA each
  resolves to before starting step 1
- You MUST NOT proceed until every constraint above holds

## Hard boundaries

These invariants hold for every step. A violation is a P0 blocker, not a
style issue. Commit bodies cite them by ID.

**Constraints:**
- **NG.1 — No CDK re-introduced.** Files under `infra/` MUST remain absent.
  Any `A infra/…` entry in a diff against upstream MUST be treated as "keep
  deleted" — never `git checkout` it. Appendix D lists the full skip set
- **NG.2 — No deletion of the Terraform tree.** Files under
  `infra-tf/` MUST NOT be removed by a sync. `D
  infra-tf/…` entries against upstream are false positives
  from upstream not carrying that tree — ignore them
- **NG.3 — No overriding supply-chain policy.** The root
  `pnpm-workspace.yaml` sets `trustPolicy: no-downgrade`,
  `blockExoticSubdeps: true`, and `minimumReleaseAge: 10080` (7 days). If
  `pnpm install` fails with `ERR_PNPM_TRUST_DOWNGRADE`, you MUST NOT disable
  the check to make it proceed
- **NG.4 — No history rewrites.** No force-push, no amend, no rewrite of
  pushed history, no `git reset --hard`. Every sync operation lands as new
  commits. You MUST NOT `git push` unless explicitly instructed
- **NG.5 — No commit without a body.** Every sync commit MUST list what was
  ported, what was skipped, and why (step 7)
- **NG.6 — No blind bulk merge.** `git merge "$UPSTREAM_TAG"` is never
  used. Selective sync per this SOP is the only supported path
- **NG.7 — Downstream edits are preserved.** CDK-to-Terraform doc rewrites,
  security-scan configs (`.ash.yaml`, `.checkov.yaml`, `.secrets.baseline`),
  `checkov:skip=CKV_DOCKER_2:` comments on batch container images, the
  `HEALTHCHECK` on the ontology-engine Dockerfile, removal of CDK deploy
  scripts under `scripts/`, and every Terraform-side decision in step 5A and
  Appendix A MUST survive the sync
- **NG.8 — `pnpm-lock.yaml` is never taken from upstream.** Upstream's
  lockfile carries `aws-cdk`, `aws-cdk-lib`, every `@aws-cdk/*`, and
  `cdk-monitoring-constructs` plus their transitive closure — dependencies
  that exist only because upstream still ships `infra/`. A checkout
  re-introduces CDK in spirit even though no CDK source lands. The lockfile
  MUST be regenerated with `pnpm install` against the CDK-free workspace
  (step 6A)
- **NG.9 — Encryption and golden-module usage are downstream platform
  decisions.** They are set by the downstream (whether enforced by an SCP,
  a platform security standard, or just team convention) — they are **not**
  CDK-derived, and a CDK change implying a different value MUST NOT be
  ported as-is:
  - *Lambda:* confirm your downstream's convention for `aws_lambda_function`.
    If every Lambda in `infra-tf/` goes through a golden Lambda module
    (e.g. `tf-module-lambda`) and no raw `aws_lambda_function` resources
    exist, any new Lambda ported from upstream MUST use that module. If raw
    Lambda resources do exist, follow their precedent and flag genuine
    uncertainty for human review. Verify current state with:
    `grep -rn 'resource "aws_lambda_function"' infra-tf/`
  - *DynamoDB / SQS / S3:* usage of golden modules vs raw resources varies.
    Some downstreams mark policy-blocked raw resources with a convention
    like `# Golden module — ... is policy-blocked.` — if yours does, locate
    them with `grep -rn "policy-blocked" infra-tf/`. Real raw
    resources may coexist with no exception comment. You MUST NOT assume a
    blanket block for these three types. For a new upstream table, queue,
    or bucket, follow the precedent in that specific service module and
    flag genuine uncertainty for human review
  - *Encryption:* confirm your downstream's S3 encryption convention
    (algorithm, key, rotation). Document and preserve any deliberate
    exceptions (e.g. a lambda-artifacts bucket on `AES256` to avoid granting
    `kms:GenerateDataKey` to every Lambda that fetches its package) —
    deliberate exceptions MUST NOT be "fixed" to the default during a sync
  - Any CDK change to an encryption setting (algorithm, key rotation,
    bucket default encryption) or that would swap a golden module for a raw
    resource (or vice versa) MUST be flagged as its own row in the step 3
    port plan for explicit human approval — never bulk-imported, never
    additively merged, never decided unilaterally by an agent
  - You MUST NOT bump a golden module's `?ref=v...` pin opportunistically
    during a sync — that is a separate, deliberate change

## Steps

The steps MUST run in order. Each ends in a verifiable state; you MAY stop
after any step and resume later with the repo in a working intermediate
state.

Every file operation MUST be idempotent — re-running it on a fresh checkout
produces a byte-identical result. That means deterministic operations only
(`git checkout <ref> -- <path>`, `str_replace` with unique anchors, `git
rm`), no whole-file `sed -i` (BSD and GNU sed diverge on regex edge cases),
and no timestamp-dependent generation.

Stack ordering governs every Terraform-touching step (port-plan priority,
commit order, validation). A later stack halts gracefully when an earlier
stack's SSM parameters aren't published yet; the reverse order creates
phantom references:

| # | Stack | Scope | Depends on |
|---|-------|-------|------------|
| 1 | `00-network` | VPC, subnets, SGs, VPC endpoints, service discovery namespace | none |
| 2 | `10-foundation` | storage, kms, authnz, guardrail, auth-idp, edge-waf | 00-network |
| 3 | `20-namespace` | namespace lifecycle Lambda + DynamoDB + platform-roles/grants API | 10-foundation |
| 4 | `25-ecr` | ECR repositories for container images | none (can run in parallel with 00) |
| 5 | `30-services` | metric-service, vkg, ontology engine | 10-foundation + 20-namespace + 25-ecr |
| 6 | `40-sources` | ingestion, enrichment, preprocessing, kg-build, Lake Formation, source-delete worker (v0.3.5), glue-event rescan (v0.3.5), Databricks parameter audit (v0.3.5) | 10-foundation + 30-services + 50-agentcore (for serve role ARN) |
| 7 | `50-agentcore` | agent runtime serving (`serve`), MCP proxy (`mcp`) | 10-foundation + 30-services |
| 8 | `55-data-layer` | data-layer Lambda (invokes the agentcore runtime — hence after 50, not 30) | 10-foundation + 50-agentcore |
| 9 | `60-api-edge` | API Gateway (from merged OpenAPI spec), CloudFront/web hosting | 10-foundation + 30-services + 40-sources + 55-data-layer (reads `/sources/api-fn-arn` for `/namespaces/{namespaceId}/sources*` — see Appendix B) |
| 10 | `70-observability` | CloudWatch alarms | all prior stacks |

### 1. Enumerate divergence

Produce the complete list of files that differ between HEAD and upstream,
grouped by top-level directory, so the operator sees the shape of the sync
before classifying anything.

```bash
mkdir -p "$SYNC_DIR"

git -P diff --name-status HEAD "$UPSTREAM_TAG" \
  > "$SYNC_DIR/diff-name-status.txt"

awk '{print $1, $NF}' "$SYNC_DIR/diff-name-status.txt" \
  | awk -F/ '{print $1"/"$2}' \
  | sort | uniq -c | sort -rn \
  > "$SYNC_DIR/diff-by-directory.txt"
```

**Constraints:**
- You MUST generate both files above from the commands shown, not by hand
- You MUST read `diff-by-directory.txt` and confirm which broad areas are in
  play. Typical shape for this repo: `packages/*` (~200 files), `libs/*`
  (~15), `models/` (~10), `external-docs/` (~10), `infra/` and
  `infra-tf/` (large, but skipped per NG.1/NG.2), and a
  handful of root files
- You MUST note whether `infra/` appears at all — if it doesn't, step 3 is
  skipped and commit chunks 1, 5, 6, 7 in step 7 are omitted
- You MUST NOT advance to step 2 until both files exist and have been read

### 2. Classify every differing file

Assign each differing file exactly one category. The category alone decides
its treatment in steps 4–5.

| Category | Definition | Treatment |
|---|---|---|
| `CLEAN` | On both sides; HEAD byte-identical to `$BASE`; upstream changed since `$BASE` | Bulk-import (step 4) |
| `NEW` | Absent on HEAD; present upstream | Bulk-import, unless on the NG.1 skip list |
| `DRIFT` | On both sides; HEAD and upstream both changed since `$BASE` | Hand-merge (step 5) |
| `OURS_ONLY` | Present on HEAD; absent upstream — or only HEAD changed since `$BASE` | Keep as-is |
| `SKIP` | Would violate NG.1 or NG.2 | Do nothing; cite in commit body |

Reference classifier:

```bash
git -P diff --name-only HEAD "$UPSTREAM_TAG" | while IFS= read -r f; do
  case "$f" in
    infra/*)       echo "SKIP     $f"; continue;;   # NG.1
    infra-tf/*)                     # NG.2, only if upstream lacks it
      if ! git cat-file -e "$UPSTREAM_TAG:$f" 2>/dev/null; then
        echo "SKIP     $f"; continue
      fi;;
    scripts/deploy*.sh|scripts/destroy.sh|scripts/preflight-deploy.sh)
      echo "SKIP     $f"; continue;;
  esac

  on_head=$(git cat-file -e "HEAD:$f" 2>/dev/null && echo Y || echo N)
  on_up=$(git cat-file -e "$UPSTREAM_TAG:$f" 2>/dev/null && echo Y || echo N)

  if   [ "$on_head" = "N" ] && [ "$on_up" = "Y" ]; then
    echo "NEW      $f"
  elif [ "$on_head" = "Y" ] && [ "$on_up" = "N" ]; then
    echo "OURS_ONLY $f"
  else
    head_drift=$(git diff --quiet "$BASE" HEAD -- "$f" && echo N || echo Y)
    up_drift=$(git diff --quiet   "$BASE" "$UPSTREAM_TAG" -- "$f" && echo N || echo Y)
    if   [ "$head_drift" = "N" ] && [ "$up_drift" = "Y" ]; then echo "CLEAN    $f"
    elif [ "$head_drift" = "Y" ] && [ "$up_drift" = "N" ]; then echo "OURS_ONLY $f"
    elif [ "$head_drift" = "N" ] && [ "$up_drift" = "N" ]; then continue
    else                                                        echo "DRIFT    $f"
    fi
  fi
done | tee "$SYNC_DIR/classification.txt" \
     | awk '{print $1}' | sort | uniq -c
```

**Constraints:**
- You MUST classify with a single deterministic script like the one above —
  never by inspection
- You MUST confirm every line of `classification.txt` carries exactly one of
  the five categories, and print the per-category counts
- You MUST justify, in the step 7 commit body, every `SKIP` outside `infra/*`
- You MUST distinguish **raw DRIFT** from **owned DRIFT** before judging the
  sync's size. With `$BASE` set to the previous synced tag this inflation is
  mostly gone, but it returns in full whenever `$BASE` falls back to the
  merge base: raw DRIFT inflates: every file a prior sync
  commit ever touched reports `head_drift=Y`, even when that touch was itself
  a resync from an older upstream. For each DRIFT file run
  `git -P log --oneline -1 HEAD -- "$f"`. If the last touch is a prior sync
  commit (identifiable via the `Upstream-Release` trailer written in step 7)
  AND the file is not on the step 5A known-owned list, it is a false-positive
  DRIFT and MAY be bulk-imported like CLEAN
- If owned DRIFT exceeds 30 files, you SHOULD split the sync into smaller
  syncs. Raw DRIFT above 30 is not by itself a reason to split — on one
  reference execution the counts were raw 101, owned 9
- You MUST NOT advance to step 3 until every DRIFT file is tagged owned or
  false-positive

### 3. Build the CDK→TF port plan

Step 2 correctly marks every `infra/**` file `SKIP`, which discards the
*intent* of upstream's CDK changes. This step recaptures that intent: for
every upstream commit touching `infra/`, map each real behavioural change to
its Terraform target. The plan also drives step 7's commit ordering.

**Fast-path skip:** if `git log --oneline "$BASE".."$UPSTREAM_TAG" --
infra/ | wc -l` returns 0, skip this step and record "no infra changes in
range" in the step 8 report.

```bash
git -P log --oneline "$BASE".."$UPSTREAM_TAG" -- infra/ \
  > "$SYNC_DIR/infra-commits.txt"

# per commit — tests and package.json bumps never have TF equivalents
git -P show --stat <commit> -- 'infra/lib/*' 'infra/bin/*'
```

**Constraints:**
- You MUST list every commit in `infra-commits.txt` in the plan
- For every changed `infra/lib/**` or `infra/bin/**` file you MUST write a
  row with:
  1. **CDK change** — the specific behavioural change (env var, IAM
     statement, resource block)
  2. **TF target** — the path under `infra-tf/modules/**`, with line
     range if known. Find it via Appendix A, then confirm with
     `grep -rn <CDK identifier> infra-tf/` (env-var name, IAM action,
     logical ID). Terraform names mostly mirror CDK names, but stack-to-module
     mapping is not 1:1 (Appendix A §A.2.2–A.2.5) — confirm, don't assume
  3. **TF state today** — already-ported, drifted, or missing
  4. **Action** — the exact edit, or "no-op" citing the file that already
     carries the equivalent
  5. **Priority** — one tier from the table below
- You MUST assign priority from this fixed set:

  | Tier | Definition | Commit timing |
  |------|------------|---------------|
  | **P0** | Fixes a broken user path (auth loop, 5xx, IAM AccessDenied, CSP block) | First, as CR-A |
  | **P1** | Feature parity: new resource, new IAM grant, tightened scope | After any app-code it depends on |
  | **P2** | Behaviour polish: retry expansion, timeout knobs, env-var renames | Bundled together |
  | **P3** | Consistency / nice-to-have: doc knobs, unused escape hatches | Optional |

- A row with an app-code dependency (e.g. a new Lambda whose handler lives in
  `packages/*/src/`) MUST be P1 or lower and MUST name the specific Python
  module or handler function. It lands after the app-code commit that ships
  that handler — otherwise `terraform apply` creates a Lambda whose handler
  string points at code not yet in the zip
- An upstream CDK `CustomResource` MUST be mapped to the action-invoke +
  `terraform_data` pattern in Reference R1, never filed as "no TF
  equivalent"
- You MUST explicitly list CDK-only changes with no TF equivalent, so
  reviewers can see they were considered. The legitimate categories are:
  - CDK synth-time validators — Terraform has no synth phase. If the guard
    is essential (e.g. region-vs-inference-profile), record it as a manual
    pre-deploy check and a follow-up deploy-script hook
  - Stack dependency ordering (`.addDependency(x)`) — module refs make it
    implicit
  - CDK-only tests (`infra/test/**`) — intent is captured by the behavioural
    rows
  - `cdk.json` synth settings
- Every NG.9 change (encryption, golden-module swap) MUST be its own row,
  marked for human review, never folded into a P1/P2 mechanical action
- You MUST write the plan to `CDK_TO_TF_SYNC_PLAN_v<N>.md` at the repo root
  (untracked), citing `$PREV_TAG`, `$UPSTREAM_TAG` and its commit SHA, and
  every reviewed commit
- You MUST NOT advance to step 4 until every row has a priority and a TF
  target file

### 4. Bulk-import CLEAN and NEW files

Bring every `CLEAN` and `NEW` file (plus false-positive DRIFT from step 2)
to upstream's version, one cohesive chunk at a time.

Chunk order — dependencies first, so you can stop after any chunk with a
working tree:

1. `libs/` — shared code; packages depend on it
2. `models/` — Smithy IDL; Python bindings depend on it (triggers step 4A)
3. `packages/sources/` — usually the most-churned package; other packages
   import its symbols
4. `packages/{context-manager,control-plane,data-layer,ontology-engine,metric-service,mcp-server,vkg}`
   — Python; one commit per package or one combined commit if all clean
5. `packages/mcp-proxy/` — TypeScript (vitest), **not** Python; never lump it
   with step-4 pytest packages
6. `packages/web-app/` — its own toolchain; MAY share a chunk with mcp-proxy
7. `external-docs/`, `scripts/`, root files — last

```bash
CHUNK_PREFIX="libs/"   # set per chunk: "models/", "packages/sources/", ...

grep -E '^(CLEAN|NEW)' "$SYNC_DIR/classification.txt" \
  | awk -v prefix="$CHUNK_PREFIX" '$2 ~ ("^" prefix) {print $2}' \
  | while IFS= read -r f; do
      git checkout "$UPSTREAM_TAG" -- "$f" \
        || { echo "FAILED: $f"; exit 1; }
    done
```

**Constraints:**
- You MUST set `CHUNK_PREFIX` to the chunk's own top-level path — `libs/`
  and `models/` are not under `packages/`
- Before the first chunk, you MUST snapshot every known-owned file (step 5A)
  into `$SYNC_DIR/owned-snapshots/` — see step 5's snapshot-then-reapply
  procedure
- You MUST NOT silently ignore a `checkout` failure — it means the
  classifier missed a case. Halt and re-classify
- You MUST NOT check out `pnpm-lock.yaml` from upstream (NG.8), even when it
  classifies as CLEAN
- After each chunk you MUST confirm `git status --short` shows the expected
  file count (the classifier's CLEAN+NEW count for that prefix) and no
  `infra/` paths
- If the chunk touched `models/`, you MUST complete step 4A before importing
  the next chunk

### 4A. Regenerate Smithy codegen and walk the UI/API/Lambda parity check

The Smithy IDL under `models/` is the single source of truth for four
gitignored artifacts, all regenerated by one script:

```
models/src/main/smithy/*.smithy
        │
        ▼  bash scripts/smithy-generate.sh
        │
        ├─→ smithy-generated/control-plane-typescript-client/  ──→ packages/web-app's @coa/control-plane-client (workspace:*)
        ├─→ smithy-generated/data-layer-typescript-client/     ──→ same, for data-layer calls
        ├─→ smithy-generated/openapi/openapi/*.openapi.json    ──→ merged via `make -C infra-tf/modules/services/api/openapi build`
        │                                                          into infra-tf/artifacts/openapi/merged.json
        │                                                          ──→ 60-api-edge's `merged_spec_path` ──→ the
        │                                                              aws_api_gateway_rest_api body
        └─→ smithy-generated/{control-plane,data-layer}-python-server/  ──→ Pydantic models the Lambda handlers import
```

This is the highest-leverage check in the sync. A new or changed Smithy
operation shows up in three places that MUST move together; missing one
produces silent three-way drift — the UI calls an endpoint the API doesn't
route, the API routes a path with no Lambda wired, or the handler expects a
payload the UI never sends. None of these produce a `terraform plan` error.

```bash
bash scripts/smithy-generate.sh

# confirm the spec filenames first — this exact pipeline has not been run
# against a live smithy-generated/ tree
find smithy-generated/openapi -name "*.json"

jq -r '.paths | keys[]' smithy-generated/openapi/openapi/*.openapi.json | sort -u \
  > "$SYNC_DIR/spec-paths.txt"
grep -oE '"/[^"]+"' infra-tf/stacks/60-api-edge/main.tf \
  | tr -d '"' | sort -u > "$SYNC_DIR/wired-paths.txt"
comm -23 "$SYNC_DIR/spec-paths.txt" "$SYNC_DIR/wired-paths.txt"
```

**Constraints:**
- You MUST run `bash scripts/smithy-generate.sh` after any `models/` import
  and before any step 6 check
- For every new or changed operation in the `models/` diff, you MUST walk
  all three surfaces — not only the ones a failing test points at:
  1. **Web app** — `packages/web-app/src/api-hooks/`,
     `src/components/*ClientProvider/`, `src/app-types/api.ts`: new call
     sites use the new operation; nothing still calls a removed or renamed
     one
  2. **API Gateway** — `60-api-edge/main.tf`'s `local.api_path_handlers`
     (Appendix A §A.2.7) has an entry mapping the new path to the Lambda that
     serves it. An unmapped path silently falls back to the 501 stub
  3. **Lambda handler** — the implementing code in `packages/*/src/` exists
     and matches the regenerated Pydantic shapes
- Every path printed by the `comm` check MUST be classified in the step 3
  plan as either intentionally unwired (not yet implemented downstream) or a
  miss to fix in this sync
- You MUST NOT treat a clean `smithy-generate.sh` run as proof of parity —
  it proves only that the codegen tooling works

### 5. Hand-merge DRIFT files

For every owned-DRIFT file, choose a merge policy and apply it. No file is
silently overwritten.

For each file, measure both sides:

```bash
ours=$(git diff --numstat "$BASE" HEAD                -- "$f" | awk '{print $1"+/"$2"-"}')
up=$(git diff --numstat "$BASE" "$UPSTREAM_TAG"       -- "$f" | awk '{print $1"+/"$2"-"}')
echo "$f  ours=$ours  up=$up"
```

then apply the first matching row:

| Pattern | Meaning | Action |
|---|---|---|
| `up=0+/0-` | Only ours drifted | **Keep ours** |
| `ours=0+/0-` | Impossible — would be CLEAN | Re-run the classifier |
| Both changed, non-overlapping regions (verify by reading both diffs) | Additive on both sides | **Merge additively** via `str_replace` at a unique anchor |
| Ours < 5 lines; upstream > 50 lines added | Small downstream tweak on a real upstream feature-doc | **Take upstream, re-apply ours** |
| Ours > 50-line Terraform rewrite; upstream small addition | Downstream doc migration; upstream added a paragraph | **Keep ours, port upstream additively** |
| Both heavy; upstream content needs CDK→Terraform translation | Not mechanically mergeable | **Defer** to a doc-translation commit (step 7 chunk 8) using Reference R2 |

**Sentinel check (doc files).** On repeat syncs HEAD often already carries
upstream's addition from a prior sync commit. Pick a unique 4+ word phrase
or code identifier from `git diff $BASE "$UPSTREAM_TAG" -- <doc>` and
run `grep -c "<phrase>" <doc>`. A count ≥ 1 means "already in sync" — skip
the reapply. (On one reference execution: four of five
`external-docs/content/*.md` files were already in sync; only
`deploying.md` needed a partial reapply.)

**Snapshot-then-reapply (known-owned files).** The safest procedure when
upstream added non-trivial content on top of a file we own edits in:

```bash
# 1. Before step 4's first chunk: snapshot every known-owned file
mkdir -p "$SYNC_DIR/owned-snapshots"
for f in \
  libs/common/src/coa_common/constants.py \
  libs/ts-shared/src/constants.ts \
  packages/sources/README.md \
  packages/sources/database/enrichment/Dockerfile \
  packages/sources/documents/preprocessing/Dockerfile \
  packages/sources/documents/kg-build/Dockerfile \
  packages/ontology-engine/Dockerfile \
  infra-tf/stacks/*/terraform.tf \
  infra-tf/stacks/*/locals.tf ; do
  [ -f "$f" ] && cp "$f" "$SYNC_DIR/owned-snapshots/$(echo "$f" | tr '/' '_')"
done

# 2. Let step 4 check them out from upstream like any other file
# 3. Diff snapshot vs current to see exactly which downstream edits were lost
diff -u "$SYNC_DIR/owned-snapshots/$(echo "$f" | tr '/' '_')" "$f"
# 4. Re-apply each lost edit via str_replace, anchored on the CURRENT file
# 5. Confirm the file now differs from upstream by exactly the downstream deltas
git diff "$UPSTREAM_TAG" -- "$f"
```

Expected residual diffs against upstream after reapply:
`libs/common/src/coa_common/constants.py` ~13+/12- (CDK→TF wording edits);
each batch `Dockerfile` 1+/2- (checkov skip);
`packages/ontology-engine/Dockerfile` 8+/0- (HEALTHCHECK);
`packages/sources/README.md` ~17+/21- (Terraform path references).

**Constraints:**
- You MUST run the numstat measurement and apply the decision table for
  every owned-DRIFT file, and record the chosen action per file for the
  commit body
- You MUST run the sentinel check before any reapply on a doc file
- For files on the step 5A list, you MUST use the recorded rule rather than
  re-deriving a policy
- Every `str_replace` anchor MUST match exactly one location in the
  *current* (post-import) file and include enough context (typically the
  section's opening marker plus 2–3 preceding lines) to stay correct on a
  re-run from a different starting state
- You MUST NOT use `sed -i` and MUST NOT use upstream line numbers as
  anchors — line numbers drift between branches
- Hand-merging MUST be the last operation on a given file before commit; no
  file is touched twice
- On any uncertainty about a DRIFT file's policy, you MUST halt and ask
  rather than guess
- Before advancing, `git diff HEAD` MUST show only intended changes

### 5A. Known-owned files and decisions

These recur on every sync of this shape. Treat them as fixed rules, not
judgment calls.

**App-code files:**

| File | What we own | Upstream typically adds | Action |
|---|---|---|---|
| `libs/common/src/coa_common/constants.py` | Three CDK→TF wording edits (header docstring, `RESOURCE_PREFIX` docstring, ARN-contract section) | New fields/constants (e.g. `preprocessingIssuesS3Key`, `DEFAULT_PREFERRED_TOPICS_JSON`) | Take upstream, re-apply the three edits |
| `libs/ts-shared/src/constants.ts` | Three comment edits (`DEFAULT_RESOURCE_PREFIX`, `DEFAULT_GRAPH_BASE_URI`, `TABLE_NAMES` header) | New constants (e.g. `DEFAULT_BEDROCK_LLM_MODEL_ID`) | Take upstream, re-apply the three |
| Batch Fargate `Dockerfile`s (`sources/database/enrichment/`, `sources/documents/kg-build/`, `sources/documents/preprocessing/`) | `# checkov:skip=CKV_DOCKER_2:` above `FROM` | Base-image digest bumps | Take upstream, re-insert the skip at the same position |
| `packages/ontology-engine/Dockerfile` | `HEALTHCHECK` block before `CMD` | Pellet-reasoner strip, digest bump | Take upstream, re-insert HEALTHCHECK before `CMD` |
| `packages/sources/README.md` | Heavy Terraform doc rewrite | New API-table rows | Keep ours; add new rows via `str_replace` |
| READMEs, top-level `Makefile`, `external-docs/{authentication-setup,getting-started,smithy-codegen}.md`, `scripts/setup-dev.sh`, `connectors/{.env.example,pnpm-workspace.yaml}`, `external-docs/pnpm-workspace.yaml` | Extensive CDK→TF rewrites | Usually nothing | Keep ours; confirm `up=0+/0-` |
| `external-docs/content/deploying.md` | Terraform doc rewrite | Feature sections referencing CDK constructs (`VkgStack`, `cdk synth`) | Keep ours; port additions in a **separate** doc-translation commit using Reference R2 |
| `.gitignore` | Our ignore entries | New ignore entries | Additive merge — **except** skip CDK-only entries (`cdk.out/`, `cdk.context.json`) |
| `pnpm-workspace.yaml` | CDK workspace entries removed; supply-chain config at top level | Similar structural fix | Keep ours if already top-level; never restore CDK entries |
| `coa-skills/control-plane/SKILL.md` | Quick Start reads the Terraform SSM names: hosted-UI domain from `/<prefix>/userpool-domain` (CDK publishes `/<prefix>/cognito-domain-prefix`, which TF does not create), and `API` from `apiEndpoint` in the SPA's `runtime-config.json` (located via `/<prefix>/web/distribution-domain-name`). `userpool-client-id` and `mcp-client-id` are the same name on both | Lifecycle notes, new API rows, Quick Start rewording | Take upstream, re-apply the SSM-name edits. After the merge, `grep -n cognito-domain-prefix coa-skills/` MUST return nothing, and every `aws ssm get-parameter --name` in the file MUST name a parameter some `infra-tf` stack writes (`grep -rn '<name>' infra-tf --include=*.tf`) |

**Terraform-side files** (upstream never touches these, but regenerating a
module from scratch to port a CDK feature can undo them):

| File | What's owned | Rule |
|------|------|------|
| `infra-tf/**/*.tf` | Entire Terraform tree; `infra/` stays absent (NG.1) | `find . -path ./infra -prune -o -name "*.ts" -type f -print` returns only test/script files, never `infra/*.ts` |
| `.buildkite/pipeline.yaml` | Buildkite CI (build-lambdas, per-stack plan/apply ordering) | Confirm its stack list still matches step 6's validate loop |
| `infra-tf/variables/apex-dev.tfvars` | Environment overrides | Never overwrite with upstream defaults; hand-merge new variables only |

**Terraform-side decisions** (apply whenever a CDK change would contradict
one):

| Area | Decision | Where | Rule |
|------|----------|-------|------|
| VPC | Custom CIDRs, subnet count, AZ distribution | `stacks/00-network/network.tf`, `modules/foundation/network` | Never regenerate from CDK context; preserve existing locals |
| Neptune | `db.r8g.large` (Graviton), backup retention | `modules/foundation/storage/neptune.tf` | Never downgrade class or backup window |
| OpenSearch Serverless | OCU min/max, index config | `modules/foundation/storage` (`aoss_min_ocu`, `aoss_max_ocu`) | Preserve defaults unless the feature set changes |
| DynamoDB | `PAY_PER_REQUEST` everywhere, AWS-managed encryption, PITR | `modules/foundation/authnz/main.tf` | Never switch to provisioned |
| Lambda runtimes | Python 3.12 across most functions (spot-checked, not exhaustive) | various | Don't drift to 3.11 without a library-compatibility check |
| IAM permission boundaries | Not implemented — no `permissions_boundary` anywhere | N/A | A gap to close if it becomes required, not a pattern to preserve |
| Golden modules | See NG.9 | `grep -rn "policy-blocked" infra-tf/modules/` | NG.9 |
| Encryption | See NG.9 | `modules/foundation/storage/s3.tf` and S3 call sites | NG.9 |

**Constraints:**
- You MUST apply the row for any file listed here instead of the generic
  decision table
- When you discover a new downstream-owned file during step 5, you MUST add
  it to this section in the same sync, with its action
- You MUST NOT remove an entry without confirming in the commit body that
  the downstream edit it protects is gone

### 6. Verify

Prove the sync didn't break the tree, cheapest check first. Halt at the
first failure and classify it before continuing.

**Terraform** — required whenever `infra-tf/**` or
`infra-tf/modules/**` changed:

```bash
(cd infra-tf && terraform fmt -recursive -check -diff)

TF_VALIDATE_FAILED=0
for stack in infra-tf/stacks/*/; do
  if terraform -chdir="$stack" init -backend=false -input=false > "$SYNC_DIR/tfinit.log" 2>&1 \
    && terraform -chdir="$stack" validate; then :
  else
    echo "FAIL in $stack"; cat "$SYNC_DIR/tfinit.log"; TF_VALIDATE_FAILED=1
  fi
done
[ "$TF_VALIDATE_FAILED" -eq 0 ] || { echo "halt — do not commit"; exit 1; }
```

**Python** — required whenever `packages/*/` or `libs/**` changed. `uv sync`
fails until `smithy-generated/` exists (it is a workspace member). Either
run step 4A then `uv sync`, or use an isolated venv:

```bash
python3 -m venv "$SYNC_DIR/testenv"
"$SYNC_DIR/testenv/bin/pip" install -q \
  pytest pytest-asyncio boto3 moto pydantic pydantic-settings \
  sqlalchemy aiohttp aioboto3 requests jsonschema python-dateutil \
  structlog aws-lambda-powertools fastapi opensearch-py pypdf pdf2image \
  pillow pypdfium2 pyjwt cryptography cedarpy httpx sse-starlette \
  networkx langfuse aiobotocore "mcp<2" bedrock-agentcore retryhttp \
  python-ulid sqlglot rdflib pyoxigraph llama-index-core \
  graphrag-lexical-graph

export PP="libs/common/src:\
packages/context-manager/src:packages/control-plane/src:\
packages/data-layer/src:packages/ontology-engine/src:\
packages/metric-service/src:packages/mcp-server/src:\
packages/vkg/src:packages/sources/src:\
smithy-generated/control-plane-python-server:\
smithy-generated/data-layer-python-server"

for pkg in libs/common packages/context-manager packages/control-plane \
           packages/data-layer packages/ontology-engine \
           packages/metric-service packages/mcp-server \
           packages/vkg packages/sources; do
  echo "===== $pkg ====="
  PYTHONPATH="$PP" "$SYNC_DIR/testenv/bin/python" -m pytest \
    -q --no-header --tb=short "$pkg/tests/unit/"
done
```

**TypeScript / web-app** — best-effort; `pnpm install && pnpm test` may be
blocked by NG.3. Fallback parse check for `.ts` (node's strip-types mode
does not handle JSX, so `.tsx` is not covered):

```bash
for f in $(git diff --diff-filter=MA --name-only HEAD -- packages/web-app/ | grep -E '\.ts$'); do
  node --check --experimental-strip-types "$f" 2>&1 | grep -q '.' && echo "FAIL $f"
done
```

**mcp-proxy** — required whenever `packages/mcp-proxy/` changed. It is
TypeScript with vitest, so neither the Python nor the web-app check covers
it:

```bash
pnpm --dir packages/mcp-proxy test
```

**Constraints:**
- `terraform fmt -check` MUST exit 0 with no diff, and every stack's
  `validate` MUST exit 0. Pre-existing `hash_key`/`range_key` DynamoDB
  deprecation warnings predate the sync and MAY be ignored
- Python tests MUST run per package — combining them collides conftest
  paths. A package passes when its summary shows `X passed` and no
  `failed`, unless every failure is unambiguously env-only (a
  `ModuleNotFoundError` during collection in the ad-hoc venv). Assertion
  failures and `AttributeError` on real symbols are code regressions and
  MUST be fixed before step 7
- A CLEAN/NEW `.tsx` file (byte-identical to upstream) MAY rely on upstream
  CI. A DRIFT `.tsx` file MUST NOT — it contains edits upstream CI never
  saw, so it needs a local typecheck or explicit human sign-off. The commit
  body MUST state, per `.tsx` file, which path was used
- If mcp-proxy's vitest suite cannot run (NG.3), you MUST fall back to the
  `node --check` loop on its `.ts` files and document why in the commit body
- If `models/` changed, you MUST re-run `smithy-generate.sh` before the
  Python and TypeScript checks (a safety net — step 4A should already have
  done it)
- **Hardening changes need a positive smoke test.** When the port plan adds
  a defensive guard (a validator, a new `sys.exit(1)` path, an assertion in
  a build-time script), you MUST run it against current inputs and confirm
  it does not fire. Reference: one such hardening added a check to the
  OpenAPI merge script to fail on path+method conflicts between the
  control-plane and data-layer specs; its smoke test was:

  ```bash
  python3 <path-to-merge.py> \
    --control-plane smithy-generated/openapi/openapi/ControlPlaneService.openapi.json \
    --data-layer    smithy-generated/openapi/openapi/DataLayerService.openapi.json \
    --cors-origin '*' --output "$SYNC_DIR/merged-check.json"
  echo "Exit: $?"   # must be 0
  ```

  The script's path predates the module reorganization in Appendix A —
  locate it under `infra-tf/modules/services/api/` first. If a guard
  fires on current content, halt: either the plan misread its intent or the
  specs genuinely need a modelling fix
- You MUST NOT bypass NG.3 to make any TypeScript check run
- Every remaining failure MUST be categorized as code-regression or
  env-only before step 7

### 6A. Regenerate `pnpm-lock.yaml`

NG.8 forbids taking upstream's lockfile. Regenerate it after step 5 so pnpm
resolves against the CDK-free workspace.

```bash
PNPM_VERSION=$(sed -n 's/.*"pnpm": *"\([^"]*\)".*/\1/p' package.json)
corepack enable && corepack prepare "pnpm@${PNPM_VERSION}" --activate
pnpm install

grep -c -E "aws-cdk|cdk-lib|cdk-monitoring" pnpm-lock.yaml   # must print 0
```

**Constraints:**
- You MUST use the repo-pinned pnpm (`package.json`'s `packageManager`
  field, resolved via corepack) — not an arbitrary system pnpm, and not
  `pnpm dlx pnpm@<x>` / `npx pnpm@<x>` (those fail with `MODULE_NOT_FOUND`
  on `pnpm/dist/worker.js`)
- If the pinned version genuinely cannot resolve the workspace, you MUST
  land a deliberate `PNPM_VERSION` bump as its own reviewed change rather
  than silently running a different pnpm (one reference execution needed
  pnpm 11.20.0)
- The CDK grep MUST include `cdk-monitoring` — `aws-cdk|cdk-lib` alone does
  not match `cdk-monitoring-constructs` and silently passes a dirty lockfile.
  It MUST print 0 before commit
- Expect a large net removal (on one reference execution: −3,829 / +725).
  A small diff SHOULD prompt a second look at whether CDK entries were
  actually stripped
- On `ERR_PNPM_TRUST_DOWNGRADE` for a package not already under
  `trustPolicyExclude`, you MUST halt (NG.3). Either add a scoped exclusion
  after evaluating the security implications, or drop the dependency
- The lockfile MUST land as its own commit (step 7 chunk 8)

### 7. Commit

Land the sync as cohesive, independently revertable commits, each after its
own step 6 checks pass. Infra chunks are woven in per the step 3 priority
order.

| # | Scope | Message |
|---|---|---|
| 1 | **Infra P0** — high-signal TF ports (CSP fixes, dropped IAM statements, S3 config unblocking a user path) | `fix(infrastructure): sync CR-A from <tag> (P0 CDK parity, <PR#>)` |
| 2 | `libs/`, `models/`, `packages/sources/` | `feat(sources+libs): sync from <tag> (<PR#>, part 1/2)` |
| 3 | Other backend Python packages | `feat(packages): sync backend packages from <tag> (<PR#>, part 2/2)` |
| 4 | `packages/mcp-proxy/` + `packages/web-app/` | `feat(web-app+mcp-proxy): sync from <tag> (<PR#>)` |
| 5 | **Infra P1** depending on chunks 2–3 app code | `fix(infrastructure): sync CR-D from <tag> (P1 <feature>, <PR#>)` |
| 6 | **Infra P1** with no app-code dependency | `fix(infrastructure): sync CR-E from <tag> (P1 <feature>, <PR#>)` |
| 7 | **Infra P2** + non-code drift (knobs, preflight scripts, workspace config) | `chore: sync CR-F sub-1 from <tag> (P2 knob + non-code drift, <PR#>)` |
| 8 | Deferred doc translations; `pnpm-lock.yaml` regeneration | `docs(<area>): port <feature> from <tag>` / `chore: regenerate pnpm-lock.yaml against the CDK-free workspace` |

Commit body template:

```
<type>(<scope>): sync <resource-name> from <tag> (<part>/<total>)

<One sentence on what this chunk accomplishes>

## Ported
- <resource or file>: <one-line intent>

## Hand-merged
- <file>: kept ours | took upstream | additive at anchor "<...>" (<SOP step>)

## Skipped
- infra/* (NG.1)
- <file> (<reason>)

## Verified
- terraform fmt: no drift; terraform validate: N/N stacks
- pytest per package: <counts>; env-only failures: <cause>
- (models/ touched) Smithy/API/web-app parity walked: N operations, all wired or deferred
- (guard added) smoke test: <result>

## Follow-up
- None | <deferred item + ticket>

Upstream-Release: <tag>

<attribution trailer, if your tooling adds one>
```

**Constraints:**
- You MUST omit chunks 1, 5, 6, 7 when step 3 was fast-path skipped. You MAY
  omit chunks 4 and 8 when nothing is in scope
- Every commit body MUST contain every section of the template, in order
  (NG.5). An empty section says "None"
- Every sync commit MUST end its body with an `Upstream-Release: <tag>`
  git trailer naming `$UPSTREAM_TAG`. The next sync discovers `$PREV_TAG`
  from it — a missing trailer forces the next operator to reconstruct the
  base by hand
- You MUST cite the SOP step for every non-obvious decision (e.g.
  "hand-merged per step 5A for constants.py")
- If Appendix A's CDK construct names don't match the real upstream
  `infra/lib/stacks/` tree, you MUST trust the upstream tree and flag the
  appendix for update in the commit body
- You MUST NOT amend, force-push, or push (NG.4)
- After the last commit, `git log --oneline "$SYNC_START"..HEAD` MUST
  show the chunks in table order, and the working tree MUST be clean apart
  from expected untracked files (the port plan, terraform lock files,
  personal notes)

### 8. Report

**Constraints:**
- You MUST report `$PREV_TAG`, `$UPSTREAM_TAG`, the commit SHA each
  resolves to, and the number of upstream commits in
  `$PREV_TAG..$UPSTREAM_TAG`
- You MUST report per-category classification counts, and raw vs. owned
  DRIFT counts — both, even when they match
- You MUST report the number of infra commits reviewed and port-plan rows by
  priority (P0/P1/P2/P3/not-ported), or state that step 3 was fast-path
  skipped
- You MUST explicitly list every NG.9 row awaiting human review, every
  deferred doc translation, and every spec path from step 4A's `comm` check
  left unwired — these are exactly the items a reviewer would otherwise miss
- You MUST report verification results per stack and per package, naming
  every env-only failure and its cause, and every check that could not run
  (e.g. vitest blocked by NG.3) — a check that didn't run MUST be
  distinguishable from one that ran and passed
- You MUST list each commit created with its SHA and subject
- You MUST list any Appendix A–D facts found stale during the sync
- You MUST NOT describe the sync as complete or verified beyond what was
  actually run; say plainly which surfaces were checked only by inspection

### 9. Cleanup

**Constraints:**
- After every commit has landed and the report is delivered, you SHOULD
  delete `CDK_TO_TF_SYNC_PLAN_v<N>.md` from the repo root and remove
  `$SYNC_DIR`
- You MUST NOT clean up if any step halted, any commit failed, or the user
  asked to keep the artifacts for review
- You MUST update Appendix C (add newly deferred items, remove landed ones)
  and Appendices A/B if module structure or SSM names changed — in a
  follow-up docs commit, never folded into a code chunk
- You MUST report what was removed

## Reference

### R1. CDK `CustomResource` → `action "aws_lambda_invoke"` + `terraform_data`

A CDK `CustomResource` (a Lambda CloudFormation invokes to do something no
native resource can — a merge-not-replace update, a value only known after
another stack applies, imperative cross-service glue) has no direct Terraform
resource. This repo's answer is a recurring pattern with three real
instances — read them before writing a fourth:

- `infra-tf/modules/foundation/web/cognito_callback_patch.tf` —
  registers CloudFront callback/logout URLs on the Cognito client, because
  the CloudFront domain isn't known until stack 60 applies
- `infra-tf/modules/foundation/web/api_cors_patch.tf` — patches API
  Gateway DEFAULT_4XX/5XX responses to the real CloudFront origin and
  force-redeploys the stage. Cites its upstream source inline
  (`infra/lib/stacks/services/web-stack.ts:317-386`) — the citation standard
  for every future instance
- `infra-tf/modules/services/sources/lakeformation_admin.tf` —
  registers a Lake Formation admin via read-then-merge, because
  `aws_lakeformation_data_lake_settings` is replace-only; its header explains
  why the native resource was rejected

**Constraints:**
- A new instance MUST have, in order:
  1. a `data.aws_iam_policy_document` + `aws_iam_policy` scoped to exactly
     the actions the patch Lambda needs — no wildcard-heavy policies
  2. a golden-module Lambda (`tf-module-lambda`, NG.9) whose package is a
     pre-built zip on S3, with the policy attached via
     `additional_policy_arns`
  3. an `action "aws_lambda_invoke" "<name>"` whose `config.payload` is the
     event the Lambda expects (requires Terraform actions, `>= 1.14`)
  4. a `resource "terraform_data" "<name>_trigger"` whose `input` holds the
     values that should cause a re-invoke, firing the action via
     `lifecycle.action_trigger` on `[after_create, after_update]`, with
     `depends_on` the Lambda module
- `action_trigger` has no destroy hook. Every instance MUST document what
  happens on `terraform destroy` (see `lakeformation_admin.tf`: the admin
  registration is left behind, harmless because the role is deleted too)
- The port-plan row MUST cite the existing file the new instance most
  resembles (usually `api_cors_patch.tf`) and note any new `payload` fields
- The deploy-time Terraform version floor is pinned in each stack's
  `terraform.tf` (`required_version = ">= 1.14"`). A sync needing a newer
  Terraform MUST bump that `required_version` on every stack, not just
  the one introducing the dependency.

### R2. CDK ↔ Terraform term mapping

Apply these when translating upstream doc content (step 5 "defer" rows).
Extend the table in the commit that first needs a new mapping.

| CDK (upstream) | Terraform (downstream) |
|---|---|
| `cdk synth` | (none — no synth phase) |
| `cdk deploy <stack>` | `terraform -chdir=infra-tf/stacks/<n>-<name> apply` |
| `--context <key>=<value>` | `-var '<key>=<value>'` or a `.tfvars` entry |
| `infra/lib/stacks/foundation/<X>-stack.ts` | `infra-tf/modules/foundation/<x>/` |
| `infra/lib/stacks/services/<X>-stack.ts` | `infra-tf/modules/services/<x>/` (also covers upstream agentcore/sources stacks — not 1:1, see Appendix A) |
| `infra/lib/context.ts` | (none — context knobs become module `variable`s) |
| `infra/lib/utils/*.ts` (build-time helpers) | `infra-tf/modules/**/*.py` if invoked at build time (e.g. OpenAPI merge), otherwise inline HCL |
| `infra/test/model-id-defaults.test.ts` | (none — no synth-time TS check) |
| `infra/bin/app.ts` | `infra-tf/stacks/*/main.tf` |
| `<Stack>` prop `camelCase` | `var.snake_case` on the module |
| `memoryLimitMiB` / `ontopJavaArgs` | `memory_limit_mib` / `ontop_java_args` |
| `preflight-deploy.sh`, `make preflight` | removed with CDK; roadmap item |
| `Runtime.PYTHON_3_12` | `runtime = "python3.12"` |
| `Duration.days(N)` | `expiration { days = N }` in `aws_s3_bucket_lifecycle_configuration` |
| `Duration.minutes(N)` | `visibility_timeout_seconds = N * 60` on `aws_sqs_queue` |
| `bucket.grantRead(fn)`, `queue.grantSendMessages(fn)` | `data.aws_iam_policy_document` + `aws_iam_policy` on the function role |
| `<Stack>.addDependency(other)` | (none — module refs are implicit) |
| Context knob with default (`tryGetContext("x") ?? "170"`) | Default in the module's `locals.tf`; add `var.<name>` only when a deployment needs to override |
| Constructor prop passed to a Lambda's env | Module input variable, merged into `local.<fn>_env` |
| CDK silent-overlay path merge (`{...spec.paths[path], ...methods}`) | Fail-loudly conflict detection in the OpenAPI merge script under `infra-tf/modules/services/api/` (step 6 smoke test) |

## Examples

### Example Input
```
upstream_url:    https://github.com/aws/context-ontology-accelerator.git
upstream_remote: aws-upstream
release_tag:     v0.3.4
previous_tag:    v0.3.3
target_branch:   feat/sync-coa-v0.3.4
sync_dir:        /tmp/upstream-sync
plan_version:    3
```

### Example Output (abbreviated — shape from one reference execution; your counts will differ)
```
PREV_TAG=v0.3.3 (<sha>)  UPSTREAM_TAG=v0.3.4 (<sha>)  <N> upstream commits in range.
Classification: CLEAN <n>, NEW <n>, DRIFT 101 raw / 9 owned, OURS_ONLY <n>, SKIP <n> (all infra/*).
Port plan v<N>: <n> infra commits reviewed → P0 <n>, P1 <n>, P2 <n>, P3 <n>, not-ported <n>.
Docs: 4 of 5 external-docs/content/*.md already in sync (sentinel check); deploying.md partially reapplied.
Hardening: OpenAPI merge now fails on path+method conflicts — smoke test exit 0 on current specs.
Lockfile: regenerated with the pinned pnpm version, −3,829 / +725; CDK grep = 0.

Needs your review:
- NG.9: <any encryption / golden-module row awaiting approval, or "none">
- Unwired spec paths from step 4A: <list, or "none">
- Not run: <e.g. mcp-proxy vitest blocked by trust policy — node --check fallback only>
```

## Troubleshooting

### `git rev-parse --verify "$UPSTREAM_TAG^{commit}"` fails
The tag isn't in this repo. Run `git ls-remote --tags aws-upstream`. If the
tag isn't listed, the release hasn't been published yet — wait for it. If no
tags are listed at all, the remote isn't the official AWS repository (check
`git remote get-url aws-upstream`); fix the URL rather than substituting a
branch tip.

### Tempted to pull a fix from upstream `main` that isn't in a release yet
Don't. The sync endpoint is always a release tag. Cherry-picking unreleased
commits breaks the `$PREV_TAG..$UPSTREAM_TAG` range the next sync depends
on. Wait for the release that contains the fix.

### Raw DRIFT is huge even though only one release elapsed
`$BASE` is almost certainly the merge base (the original fork point) rather
than the previous synced tag. Re-derive `$PREV_TAG` from the
`Upstream-Release` trailer, or set `previous_tag` explicitly.

### Tempted to `git merge "$UPSTREAM_TAG"` to save time
Don't (NG.6). It produces hundreds of "added by them / deleted by us"
conflicts on the CDK tree, buries the real app-code conflicts among them,
and is unreviewable. The classifier exists so each file gets an explicit,
recorded decision.

### Raw DRIFT count is far above 30
Usually not a real problem. Prior sync commits make every file they ever
touched look DRIFT. Separate owned from false-positive DRIFT per step 2 —
only owned DRIFT above 30 is a reason to split the sync.

### `git checkout "$UPSTREAM_TAG" -- <file>` fails with "did not match any file(s)"
The classifier mislabeled the file (e.g. CLEAN for a file absent on one
side) or it was never actually in sync. Re-run step 2 and reclassify —
usually as NEW.

### `ERR_PNPM_TRUST_DOWNGRADE` during `pnpm install`
A package lacks trust evidence at the registry. Do NOT bypass (NG.3).
Either add a scoped `trustPolicyExclude` entry after evaluating the security
implications, or document it as an environment limitation and fall back per
step 6.

### `pnpm-lock.yaml` now contains `aws-cdk` / `aws-cdk-lib` / `cdk-monitoring` entries
It was checked out from upstream (NG.8 violation). Restore it with
`git checkout HEAD -- pnpm-lock.yaml` and regenerate per step 6A.

### `pnpm install` via `pnpm dlx pnpm@<version>` fails with `MODULE_NOT_FOUND` on `pnpm/dist/worker.js`
`dlx`/`npx` installs pnpm into a nested `node_modules/.pnpm/...` path whose
runtime lookup breaks during a workspace install. Use the corepack-pinned
version from step 6A.

### pytest `AttributeError: type object 'VkgHealthStatus' has no attribute 'DEGRADED'`, or `ImportError` from `coa_control_plane_server`
`smithy-generated/` is stale or missing — the IDL was imported without
regenerating bindings. Run `bash scripts/smithy-generate.sh`. For a
`ModuleNotFoundError` on the same module, also confirm both
`smithy-generated/*-python-server` paths are on `PYTHONPATH`.

### `uv sync` fails: `coa-control-plane-server references a workspace ... but is not a workspace member`
`smithy-generated/` has never been generated on this checkout. Run
`bash scripts/smithy-generate.sh` first.

### pytest `ImportPathMismatchError: tests.unit.conftest`
Several packages' conftests collided in one invocation. Run per package
(step 6).

### Smithy codegen fails with "Failed to build Smithy models"
Java or Gradle isn't on `PATH`. Recheck the toolchain precondition and
install the JDK version pinned in `models/gradlew`.

### `terraform validate` fails with "Reference to undeclared resource" after an import
A module references a resource that wasn't brought in, or a NEW resource
landed without its module dependency. Check which `stacks/*/main.tf`
calls the module, confirm its inputs exist, and re-run step 2.

### `terraform plan` shows unexpected deletions
A module output was renamed but a consumer still reads the old SSM key.
Compare the module's `outputs.tf` with every `data.aws_ssm_parameter` read
(Appendix B).

### SSM parameter not found in a downstream stack
Name mismatch between producer and consumer — or the producing module
writes the parameter internally rather than the stack file doing it, so
grepping only the stack's `main.tf` misses it. Check module source too
(Appendix B notes `data-layer` and `namespace` do this).

### A ported resource's consumer lives in a different stack
Cross-stack plumbing is required: create the resource in its module →
publish an output → write an SSM parameter in the producer stack → read it
with a data source in the consumer stack → wire a local and module input.
Model it on an existing chain in Appendix B (e.g. `00-foundation`
publishing a security-group ID that `40-sources` reads).

### `terraform fmt` reports a diff after a `str_replace` on a `.tf` file
Alignment shifted. Run `terraform fmt -recursive` (without `-check`) to
normalize, then re-validate.

### A web-app `.tsx` file fails `node --check --experimental-strip-types`
Expected — strip-types mode doesn't implement JSX. Not a failure. Apply
step 6's CLEAN/NEW vs. DRIFT rule to decide how it gets verified.

### Freshly imported code mentions CDK in comments (`infra/lib/`, `cdk deploy`, `# CDK`)
If it's comments only and the code is Terraform-neutral, leave it and
batch the wording into a doc-translation commit — don't block the code
chunk on it.

### Tempted to "fix" the lambda-artifacts bucket's `AES256` to KMS
Don't. It's a documented, deliberate exception (NG.9), not a gap.

### Tempted to assert "DynamoDB/SQS/S3 must always use golden modules"
The code doesn't support that claim — real raw resources exist without
exception comments (NG.9 lists them). Follow the precedent in the specific
module and flag uncertainty for review instead of stating a rule this SOP
can't verify.

### Tempted to trust Appendix A's line counts or construct names without checking
Don't. They were true at the last sync and drift with every module change.
Re-run `wc -l` / `grep` against source, and where upstream's real
`infra/lib/stacks/` tree disagrees with the appendix, trust upstream and
flag the appendix in the commit body.

### Tempted to treat a CDK `CustomResource` as "no Terraform equivalent"
It has one — Reference R1. File it as a mapped row, not under "not ported."

---

## Appendix A: Terraform Stack & Module Inventory

**This appendix goes stale every sync — re-verify against source (`wc -l` on modules, `grep` for `module` blocks in each stack) before trusting any number here. Do not summarize secondhand from a prior audit; check the files directly.** Last verified 2026-10-14 against COA v0.3.5 on this downstream (stacks live at `infra-tf/stacks/`, modules at `infra-tf/modules/`; stack numbering 00-network / 10-foundation / 20-namespace / 25-ecr / 30-services / 40-sources / 50-agentcore / 55-data-layer / 60-api-edge / 70-observability).

### A.1 Stack structure

**Last verified: 2026-10-14 against COA v0.3.5 on this downstream.** Re-verify
with `wc -l` and `grep` before trusting any number below.

This downstream organizes infrastructure into **numbered stacks**
(`infra-tf/stacks/<N>-<name>/`), each consuming module outputs via SSM and
emitting their own via SSM parameters. No direct module-to-module refs
cross stacks. All modules live under `infra-tf/modules/{foundation,
services}/` plus one standalone `observability` module — there is no
separate `agentcore` or `sources` module namespace; those names describe
stacks, not module directories. The stack numbering diverges from
upstream CDK's own layout (upstream merges network+auth into a single
`00-foundation`; this downstream splits them into `00-network`,
`10-foundation`, `20-namespace`, `25-ecr`).

| Stack | Purpose | Modules called (real paths, real line counts) | Publishes to SSM |
|-------|---------|---------|------------------|
| **00-network** | VPC, subnets, security groups, VPC endpoints, service discovery namespace | `network` (1,292L) | `/network/{vpc-id,private-subnet-ids,vpc-cidr-block}`; per-SG IDs for AOSS/Lambda/ECS/Neptune/connector/discovery-ocsp; AOSS VPC endpoint ID; service namespace ARN/name/id; AgentCore-supported AZ names |
| **10-foundation** | Storage (S3, Neptune, AOSS NEXTGEN), KMS, authnz tables, Bedrock guardrails, IdP (Cognito/SAML/OIDC), edge WAF | `storage` (792L), `kms` (158L), `authnz` (494L), `guardrail` (329L), `auth-idp` (522L), `edge-waf` (161L) | ontology/opensearch/neptune/athena bucket names + ARNs; `/storage/opensearch-collection-arn`; `/storage/neptune-cluster-arn-full`; `/authnz/{roles,resource-role-mappings,cache-invalidation}-table-{arn,stream-arn}`; `/kms/{ssm,logs}-key-arn`; `/issuer`, `/mcp-client-id`, `/smus/domain-id` |
| **20-namespace** | Namespace lifecycle (create/list/status), namespace-scoped DynamoDB, platform-roles/grants API | `namespace` (2,269L, 9 files — largest module on this downstream) | `/namespace/{namespaces-table-arn,api-fn-arn,grants-api-fn-arn,platform-roles-api-fn-arn,roles-api-fn-arn}` |
| **25-ecr** | ECR repositories for Fargate/Lambda container images | — (inline `aws_ecr_repository` resources) | `/ecr/{repo}/url`, `/ecr/{repo}/arn` × N repos |
| **30-services** | Metric service, VKG, ontology engine | `metric-service` (1,075L), `vkg` (814L), `ontology` (961L) | service role ARNs; cluster/service names; `/metric/{api,import-worker,import-dlq-recovery}-fn-arn`; `/vkg/cluster-name`; `/ontology-engine/{cluster-name,api-fn-arn}` |
| **40-sources** | Data connectors (ingestion, enrichment, preprocessing, kg-build), Lake Formation, source-delete worker, glue-event rescan (v0.3.5), Databricks parameter audit (v0.3.5) | `sources` (5,124L, 20 files — single consolidated module, grew from 4,321L in v0.3.4 for the new flows) | `/sources/api-fn-arn`; `/sources/{db-connector,bulk-review-worker,preprocessing,db-scan-trigger,doc-cleanup,doc-trigger,federation-provisioner,delete-worker,glue-event-rescan}-fn-arn`; `/sources/{db-scan,bulk-review,doc-ingestion,source-delete,glue-event}-dlq-arn` |
| **50-agentcore** | Agent runtime serving, MCP proxy | `serve` (1,164L, 8 files — Fargate + AOSS proxy Lambda), `mcp` (523L, 6 files — Fargate) | `/serve/{aoss-proxy-fn-arn,runtime-arn}`; `/serve/${env}/runtime-role-arn` (env-scoped post-v0.3.5 to avoid cross-env collision); MCP endpoint |
| **55-data-layer** | Data-layer Lambda (invokes agentcore runtime) | `data-layer` (268L, 5 files) | `/data-layer/api-fn-arn` (written by module internals, not stack) |
| **60-api-edge** | API Gateway routing (merged OpenAPI → `aws_api_gateway_rest_api`), CloudFront + web hosting, 501-stub guard (v0.3.5) | `api` (1,269L, 10 files — grew from 1,182L in v0.3.4 for the stub guard), `web` (942L — CloudFront + S3 + Cognito callback) | `/api/rest-api-id`; `/api/cache-invalidation-dlq-arn`; `/web/website-bucket-name` |
| **70-observability** | CloudWatch alarms (Lambda, state machines, DLQs, DynamoDB, APIs, ECS) | `observability` (494L, 5 files) | nothing to SSM — terminal stack, alarms + SNS routing |

All `services/*` modules are called with `source = "../../../modules/services/<name>"`; all `foundation/*` modules with `source = "../../../modules/foundation/<name>"`.

### A.2 CDK Construct ↔ Terraform Mapping, per stack

#### A.2.1 Foundation Stack (`infra/lib/stacks/foundation/foundation-stack.ts`)

Upstream collapses network + auth + storage into one CDK `foundation` stack.
This downstream splits them: network is its own stack (`00-network`), everything
else from upstream's foundation lives in `10-foundation`, and namespace is split
again into `20-namespace`. The TF stack files are per-concern (`main.tf` plus
`locals.tf`, `outputs.tf`, etc.), not CDK's `foundation.tf` + `namespace.tf`
pattern.

| CDK Construct | Intent | Terraform Mapping | Module |
|---|---|---|---|
| **NetworkStack** (VPC, subnets, SGs, endpoints) | AWS network fabric | `module.network` in `stacks/00-network/main.tf` | `modules/foundation/network` (1,292L) |
| **StorageStack** | S3 buckets, Neptune, OpenSearch Serverless NEXTGEN | `module.storage` in `stacks/10-foundation/main.tf` | `modules/foundation/storage` (792L) |
| **KmsStack** | KMS keys for SSM / Logs / SNS encryption | `module.kms` in `stacks/10-foundation/main.tf` | `modules/foundation/kms` (158L) |
| **AuthnzStack** | DynamoDB tables (roles, resource-role-mappings, cache-invalidation) + group-mapping seed items (sanitize_principal_key as of v0.3.5) | `module.authnz` in `stacks/10-foundation/main.tf` | `modules/foundation/authnz` (494L) |
| **GuardrailStack** | Bedrock guardrails (primary with HIGH prompt-attack + PII mask + topic policy + contextual grounding v0.3.5; retrieval tuned looser) | `module.guardrail` in `stacks/10-foundation/main.tf` | `modules/foundation/guardrail` (329L) |
| **IdpAuthenticationStack** (Cognito / SAML / OIDC) | User pool, user pool client, SAML/OIDC providers | `module.auth_idp` in `stacks/10-foundation/main.tf` | `modules/foundation/auth-idp` (522L) |
| **NamespaceStack** | Namespace lifecycle (create/list/status), namespace-scoped DynamoDB | `module.namespace` in `stacks/20-namespace/main.tf` | `modules/services/namespace` (2,269L, 9 files — note: lives under `services/`, not `foundation/`) |
| — (new in this downstream) | Edge WAF ACL for CloudFront | `module.edge_waf` in `stacks/10-foundation/main.tf` | `modules/foundation/edge-waf` (161L) |

#### A.2.2 Services Stack (`infra/lib/stacks/services/services-stack.ts`)

| CDK Construct | Intent | Terraform Mapping | Module |
|---|---|---|---|
| **MetricServiceStack** | Metric service Lambda + Fargate | `stacks/30-services/main.tf` → `module.metric_service` | `modules/services/metric-service` (1,075L, 6 files) |
| **VkgStack** | Versioned knowledge graph Fargate service | `stacks/30-services/main.tf` → `module.vkg` | `modules/services/vkg` (814L, 6 files) |
| **OntologyStack** | Ontology engine Fargate + Lambda | `stacks/30-services/main.tf` → `module.ontology` | `modules/services/ontology` (961L, 9 files) |
| **McpProxyStack** | MCP proxy Fargate cluster | Lives under `50-agentcore`, module `mcp` (§A.2.5) | `modules/services/mcp` (523L) |
| **DataLayerServiceStack** | Data-layer Lambda | Lives in `55-data-layer` to break a circular dependency (data-layer needs agentcore's runtime ARN) | see §A.2.4 |

No `control-plane` or standalone `api` module exists under `30-services`. API routing lives entirely in `60-api-edge` (§A.2.7).

#### A.2.3 Sources Stack (`infra/lib/stacks/sources/sources-stack.ts`)

The Terraform side is a **single consolidated module** (`modules/services/sources`, 5,124 lines across 20 files as of v0.3.5 — grew from 4,321L for the async DELETE + glue-event rescan + Databricks audit flows) called once from `stacks/40-sources/main.tf` — not separate per-concern modules.

| CDK Construct (assumed) | Intent | Terraform Mapping | Module | Status | Notes |
|---|---|---|---|---|---|
| Ingestion connectors (Fivetran, Salesforce, etc.) | Data connector Lambdas + SQS + DLQs | `40-sources/main.tf` → `module.sources` | `modules/services/sources` (4,321L, 18 files) | 🔶 Ported | Lambda handlers, SQS queues, DLQs present within the consolidated module |
| Enrichment | Enrichment Lambda + Fargate batch | same module | same | 🔶 Ported | Fargate task defs present; some DB enrichment timeouts hardcoded |
| Preprocessing | Document preprocessing Lambda | same module | same | 🔶 Ported | |
| KG Build | Fargate batch for knowledge graph build | same module | same | 🔶 Ported | Step Functions workflows present |
| Sources API | API Gateway / Lambda proxy | same module | same | 🔶 Ported | |
| Lake Formation integration | Data lake permissions | same module | same | 🔶 Ported | `lakeformation_admin` S3 config is external (not fully TF-managed) |

Publishes 12 SSM outputs (Lambda ARNs, DLQ ARNs, state machine ARNs, DynamoDB table names) consumed by `70-observability` and elsewhere.

#### A.2.4 Data Layer Stack (`infra/lib/stacks/data-layer/data-layer-stack.ts`)

The thinnest stack in the repo — one module, Lambda-only, no API Gateway. Exists specifically to hold the data-layer Lambda that invokes the agentcore runtime, keeping stack 50 (agentcore) and stack 30 (services) from forming a circular dependency.

| CDK Construct (assumed) | Intent | Terraform Mapping | Module | Status | Notes |
|---|---|---|---|---|---|
| **DataLayerServiceStack** | Data layer Lambda | `55-data-layer/main.tf` → `module.data_layer` | `modules/services/data-layer` (235L total, 5 files; 101L in `main.tf` alone) | 🔶 Ported | Reads `serve-runtime-arn` from stack 50 via SSM, wires it as a Lambda invoke permission |
| **DataStoreStack** (Neptune, DynamoDB) | Graph database + transactional storage | Lives in `00-foundation` (`module.storage`), not here | `modules/foundation/storage` | ✅ Ported | Storage resources are entirely in foundation; nothing data-store-specific lives in stack 55 |

#### A.2.5 Agent Core Stack (`infra/lib/stacks/agent-core/agent-core-stack.ts`)

No Bedrock agent resource, tool-executor, or federation-provisioner module exists anywhere in this stack. The actual implementation is two Fargate-based modules: `serve` (agent runtime + an AOSS proxy Lambda) and `mcp` (MCP proxy Fargate service). If upstream CDK genuinely has a `BedrockAgentStack`/`ToolExecutorStack`/`FederationProvisionerStack`, those are real gaps — but re-verify their existence in the upstream tree before treating this as ❌ Not Yet Ported; it's equally possible this repo's implementation (Fargate-hosted agent runtime) is an intentional architectural divergence from a Bedrock-native upstream.

| CDK Construct (assumed) | Intent | Terraform Mapping | Module | Status | Notes |
|---|---|---|---|---|---|
| Agent runtime serving (assumed `BedrockAgentStack` equivalent) | Agent runtime + tool invocation surface | `50-agentcore/main.tf` → `module.serve` | `modules/services/serve` (1,093L, 8 files) | 🔶 Ported | Fargate + AOSS proxy Lambda; reads 33 SSM params; publishes `serve-runtime-arn` |
| MCP proxy | MCP proxy Fargate service | `50-agentcore/main.tf` → `module.mcp` | `modules/services/mcp` (551L, 6 files) | 🔶 Ported | Fargate cluster/service; publishes MCP endpoint |
| **BedrockAgentStack** (if distinct from `serve`) | Bedrock agent definition, action groups | ❓ Unverified | — | ❓ Needs upstream re-check | Do not mark ❌ without confirming this construct still exists upstream |
| **ToolExecutorStack** | Lambda tool executor | ❓ Unverified | — | ❓ Needs upstream re-check | |
| **FederationProvisionerStack** | Federation provisioner (role sync) | ❓ Unverified — may overlap with `authnz` module (§A.2.1) | — | ❓ Needs upstream re-check | Check `module.authnz` claims_mappings logic before assuming this is missing |

#### A.2.6 Observability Stack (`infra/lib/stacks/observability/observability-stack.ts`)

| CDK Construct | Intent | Terraform Mapping | Module | Status | Notes |
|---|---|---|---|---|---|
| **CloudWatchAlarmsStack** | Alarms (Lambda errors, DynamoDB throttling, DLQ depth, state machines, API latency, ECS tasks) | `70-observability/main.tf` | `modules/observability` | ✅ Ported | Alarms created for Lambda, state machines, DLQs, DynamoDB, REST APIs, Fargate ECS services |
| **CloudWatchDashboardStack** | CloudWatch dashboards | Deferred | — | 🔶 Partial | Alarm infrastructure present; dashboards not yet scoped |
| **XRayStack** | X-Ray sampling rules, groups | Deferred | — | 🔶 Partial | Roadmap item for tracing |

The observability module reads SSM parameters from upstream stacks to create CloudWatch alarms for: Lambda functions, Step Functions state machines, SQS DLQs, DynamoDB tables, API Gateway REST APIs, and ECS Fargate services.

#### A.2.7 API Edge Stack (`infra/lib/stacks/api-edge/api-edge-stack.ts`)

There is a real API Gateway — a single **REST API Gateway** (`aws_api_gateway_rest_api`) built from a merged OpenAPI spec, not a hand-written tree of `aws_api_gateway_resource`/`aws_api_gateway_method` blocks per route. There is no ALB in front of the API; it's API Gateway directly, optionally behind CloudFront.

| CDK Construct (assumed) | Intent | Terraform Mapping | Module | Status | Notes |
|---|---|---|---|---|---|
| **ApiEdgeStack** (OpenAPI merge, routing, WAF) | Merged OpenAPI spec → API Gateway, custom domain, regional WAF | `60-api-edge/main.tf` → `module.api` | `modules/services/api` (1,182L, 10 files) | ✅ Ported | REST API built via `body = jsonencode(local.enriched_spec)`; spec loaded from `merged_spec_path` (produced by a Makefile merge step) |
| Per-path Lambda proxy integration | Route each OpenAPI path to its owning service Lambda | `60-api-edge/main.tf` → `local.api_path_handlers` (105 entries) → `var.path_handlers` (this map lives in the **stack**, not the module — see step 4A's parity check) | same module | ✅ Ported | Falls back to the 501 stub Lambda for any spec path with no handler wired |
| 501 "Not Implemented" stub | Fallback for any spec path not yet wired to a real handler | `modules/services/api/stub.tf` | same module | ✅ Ported (intentional) | Authorizer still protects these routes unless in `unsecured_paths` |
| Custom authorizer | Auth check on protected routes | `modules/services/api/authorizer.tf` (84L) | same module | ✅ Ported | |
| Cache invalidation | Invalidate downstream caches on writes | `modules/services/api/cache_invalidation.tf` (169L) | same module | ✅ Ported | Own DLQ + alarm hook |
| Regional WAF on API stage | WAF ACL on the REST API stage | `modules/services/api/waf.tf` (153L) | same module | ✅ Ported | |
| Custom domain + Route53 alias (optional) | `api.<domain>` → API Gateway | `modules/services/api/main.tf` | same module | ✅ Ported | Gated on `var.custom_domain != null` |
| CloudFront + S3 web hosting | Static frontend + CDN | `60-api-edge/main.tf` → `module.web` | `modules/foundation/web` (914L) | ✅ Ported | Also patches the Cognito callback URL post-apply |

### A.3 Known-Owned Terraform Files & Decisions

See step 5A for the current, canonical version of this list — it lives there now so it's next to the hand-merge decision procedure that uses it.

---

## Appendix B: Cross-Stack SSM Dependency Graph

Grounded in real parameter names under `${local.ssm_prefix}/...`. Same staleness caveat as Appendix A — verify with `grep` before trusting.

```
00-foundation
  Publishes: /ecr/{repo}/url, /ecr/{repo}/arn (7 ECR repos)
             /namespace/namespaces-table-arn  (NOTE: namespace module writes its own)
             /authnz/roles-table-arn, /authnz/roles-table-stream-arn
             /authnz/resource-role-mappings-table-{arn,stream-arn}
             /authnz/cache-invalidation-table-arn
             /storage/ontology-bucket-arn, /storage/opensearch-collection-arn
             /storage/neptune-cluster-arn-full
             /storage/athena-{results,spill}-bucket-{name,arn}
             /network/{vpc-id, private-subnet-ids, vpc-cidr-block}
             /network/{aoss,lambda,ecs,neptune,connector,discovery-ocsp}-security-group-id
             /network/aoss-vpc-endpoint-id, /network/service-namespace-{id,name,arn}
             /network/agentcore-supported-az-names
             /kms/{ssm,logs}-key-arn
             /issuer, /mcp-client-id, /smus/domain-id  (auth-idp outputs)

05-lambda-artifacts
  Publishes: /lambda-artifacts/{bucket-name, s3-path, buildkite-upload-role-name}

30-services  (metric-service, vkg, ontology modules)
  Reads:     00-foundation (ecr, kms, network, opensearch, namespace-table-name, smus/domain-id)
  Publishes: /metric/{import-worker-fn-arn, import-dlq-arn, import-dlq-recovery-fn-arn}
             /ontology-engine/cluster-name, /vkg/cluster-name

40-sources  (single `sources` module)
  Reads:     00-foundation (ecr, kms, network, opensearch, namespace-table, smus)
  Publishes: /sources/api-role-arn, /sources/{db-connector,bulk-review-worker,preprocessing,
             db-scan-trigger,doc-cleanup,doc-trigger,federation-provisioner}-fn-arn
             /sources/{db-scan,bulk-review,doc-ingestion}-dlq-arn
             /sources/doc-deletion-state-machine-arn
             (12 SSM outputs total)

50-agentcore  (serve, mcp modules)
  Reads:     00-foundation (authnz tables, ecr, kms, network, namespace-table)
             30-services (/metric/api-fn-arn)
  Publishes: /serve/aoss-proxy-fn-arn, /serve/runtime-arn (read by 55-data-layer)
             MCP endpoint (module output, not confirmed as a separate SSM write — verify next sync)

55-data-layer  (data-layer module)
  Reads:     00-foundation (network, namespace-table-name)
             50-agentcore (/serve/runtime-arn — this is the circular-dependency-breaking read)
             /ontology-engine/api-fn-arn (30-services)
  Publishes: /data-layer/api-fn-arn  (written by the module itself, not the stack — main.tf has no
             stack-level aws_ssm_parameter resources, easy to miss on a first pass)

60-api-edge  (api, web modules)
  Reads:     00-foundation (network vpc-id/private-subnet-ids/lambda-security-group-id,
             authnz tables incl. cache-invalidation, kms logs key, lambda-artifacts upload role)
             30-services (/metric/api-fn-arn)
             40-sources (/sources/api-fn-arn — routes /namespaces/{namespaceId}/sources*)
             50-agentcore (/serve/runtime-arn)
             55-data-layer (/data-layer/api-fn-arn)
             /ontology-engine/api-fn-arn (30-services)
             namespace module outputs (/namespace/{api,grants-api,platform-roles-api,roles-api}-fn-arn)
  Publishes: /api/rest-api-id, /api/cache-invalidation-dlq-arn, /web/website-bucket-name

70-observability  (observability module)
  Reads:     30-services, 40-sources, 50-agentcore, 55-data-layer outputs — 24 SSM params total
             (Lambda ARNs, DLQ ARNs, state machine ARNs, DynamoDB table names, cluster/service names)
  Publishes: nothing to SSM — terminal stack, alarms + SNS topic only
```

**Gotcha:** `data-layer` and `namespace` publish SSM params from inside the module rather than the stack file — if you grep only the stack-level `main.tf` for `aws_ssm_parameter` you'll wrongly conclude a stack "publishes nothing." Check module source too.

**Sync Rule:** When porting a CDK change that affects a module's output, **MUST** verify downstream SSM parameter names match exactly (`grep -r "<param-name>" infra-tf/` both for the write and every read) — check module-internal writes, not just the stack file. A mismatch breaks the dependency chain silently.

---

## Appendix C: Deferred Work Tracker

| Item | Reason | Deferred To | Ticket |
|------|--------|------------|--------|
| Observability dashboards | CloudWatch alarms are ported (§A.2.6); dashboard widgets not yet scoped | 70-observability follow-up | TBD |
| X-Ray sampling rules | Not yet ported; roadmap item for distributed tracing | 70-observability follow-up | TBD |
| DLQ recovery Lambda coverage gaps | Some DLQs may lack a paired recovery Lambda — confirm which ones during next sync | 70-observability follow-up | TBD |
| Fargate replica counts hardcoded | 30-services modules (metric-service, vkg, ontology) have hardcoded replica counts for initial smoke test, not yet variable-driven | 30-services follow-up | TBD |
| Re-verify upstream construct names for §A.2.5 | This doc's CDK-side labels for agentcore (`BedrockAgentStack`, `ToolExecutorStack`, `FederationProvisionerStack`) are unverified guesses — confirm against the real upstream `infra/lib/stacks/agent-core/` tree on next sync | Next COA sync, step 1 | TBD |
| VPN/connector-specific pieces in 40-sources | Marked optional in current implementation; confirm which are required for prod | 40-sources follow-up | TBD |
| Cross-stack SSM param naming standardization | Upstream CDK may emit different SSM keys; manual reconciliation per stack | Step 5 hand-merge | TBD |
| ReservedRoleNamePrefix precommit check (v0.3.5 row 7) | CDK aspect from v0.3.5 enforces that no COA-internal `iam.CfnRole` falls under `${prefix}-${env}-datasource-access-*`. No Terraform synth-phase equivalent — candidate for a precommit grep on `name = "...-datasource-access-..."` in `aws_iam_role` resources | Repo tooling follow-up | TBD |
| Databricks managed-connector TF port (v0.3.5) | Upstream deploys `connectors/databricks` via its own CDK app + two deploy scripts (`deploy-serve.sh`, `deploy-managed-databricks-connector.sh`). This downstream removed those scripts (NG.7). A standalone, reusable Terraform module landed at `infra-tf/modules/connectors/databricks/` (supports both `environment` and `coa-managed` modes). It is **not** called by any stack and **not** on any Makefile deploy target — anyone who needs the connector calls the module from their own TF configuration. Related upstream deploy-doc sections (Cross-architecture container builds, Databricks SQL Warehouse connector) remain deferred until a deploy path lands | Connectors TF migration (module landed; deploy path open) | TBD |
| `llama-index-core` as libs/common dev dep | 7 new upstream v0.3.5 tests in `libs/common/tests/unit/test_embeddings.py` import `llama_index.core.base.embeddings.base` directly, but `llama-index-core` isn't declared as a dep of `libs/common`. Options: add it as a dev dep, wrap imports in `pytest.importorskip`, or accept as env-only (upstream pattern probably has it at workspace level) | Next test cleanup | TBD |

After every sync, update this tracker: add newly-deferred items, remove items that landed, and update Appendix A/B if module structure or SSM names changed.

---

## Appendix D: NG.1 Skip List

Files that **MUST NOT** be re-introduced:

```
infra/
├── lib/
│   ├── context.ts
│   ├── index.ts
│   ├── stacks/
│   │   ├── foundation/
│   │   ├── services/
│   │   ├── sources/
│   │   ├── data-layer/
│   │   ├── agent-core/
│   │   └── observability/
│   ├── constructs/
│   ├── utils/
│   └── *.ts
├── bin/
│   └── app.ts
├── test/
│   └── *.test.ts
└── cdk.json

scripts/
├── deploy.sh (removed; use terraform apply)
├── destroy.sh (removed; use terraform destroy)
├── preflight-deploy.sh (removed)
└── (other CDK-related scripts)
```

If `git diff` shows any `A infra/` or `A scripts/deploy*.sh` entries, treat as SKIP (NG.1).
