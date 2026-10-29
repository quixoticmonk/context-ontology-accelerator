#!/usr/bin/env bash
# Post-deploy smoke test for a COA Terraform deployment.
#
# Read-only health checks that answer one question: did `make up-all` leave a
# working environment, and did this sync introduce a regression? Run it after
# every deploy: `make smoke` (from infra-tf/) or `bash scripts/smoke-test.sh`.
#
# Endpoints are resolved live from the deployment's own source of truth — SSM
# (`/<prefix>/web/distribution-domain-name`, `/<prefix>/bedrock/guardrail-id`)
# and the SPA's `runtime-config.json` (`apiEndpoint`) — falling back to
# `terraform output` only when SSM is unavailable. Nothing is hardcoded, and an
# explicit override is honored (SCL_CF_DOMAIN / SCL_PREFIX / SCL_ENV / AWS_REGION).
# Exits non-zero if any non-skipped check fails. Tier 1 needs network access and
# either AWS read creds (SSM) or local TF state; Tier 2 needs AWS read creds;
# Tier 3 (--auth) needs a Cognito web login.
set -uo pipefail

# ── Locate the repo + infra dirs regardless of CWD ──────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA="$REPO_ROOT/infra-tf"
TF="${TF:-terraform}"
WITH_AUTH=0
for arg in "$@"; do [ "$arg" = "--auth" ] && WITH_AUTH=1; done

# ── Resolve region + name prefix from shared.tfvars (env/args override) ─────
tfvar() { awk -F'=' -v k="$1" '$1 ~ "^[[:space:]]*"k"[[:space:]]*$" {gsub(/[" ]/,"",$2); print $2}' "$INFRA/shared.tfvars" 2>/dev/null | head -1; }
REGION="${AWS_REGION:-$(tfvar region)}"; REGION="${REGION:-us-east-1}"
RESOURCE_PREFIX="${SCL_PREFIX:-$(tfvar resource_prefix)}"; RESOURCE_PREFIX="${RESOURCE_PREFIX:-coa}"
ENVNAME="${SCL_ENV:-$(tfvar env)}"; ENVNAME="${ENVNAME:-dev}"
SSM_PREFIX="/$RESOURCE_PREFIX"          # e.g. /coa  (ssm_prefix = "/${resource_prefix}")
PREFIX="$RESOURCE_PREFIX-$ENVNAME"      # resource name prefix, e.g. coa-dev

out() { $TF -chdir="$INFRA/stacks/$1" output -raw "$2" 2>/dev/null; }

PASS=0; FAIL=0; SKIP=0
ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=$((FAIL+1)); }
skip() { printf '  \033[33mSKIP\033[0m  %s  (%s)\n' "$1" "$2"; SKIP=$((SKIP+1)); }

echo "== COA post-deploy smoke test =="
echo "region=$REGION  prefix=$PREFIX"

# ── Resolve deployment identifiers from the deployment's OWN source of truth ─
# Canonical order: explicit override -> SSM / runtime-config.json (published by
# the deploy, readable with just AWS creds) -> terraform output (fallback, needs
# local state). The endpoint is never hardcoded and never baked into the script.
ssm() { aws ssm get-parameter --name "$1" --region "$REGION" --query Parameter.Value --output text 2>/dev/null; }

CF="${SCL_CF_DOMAIN:-}"
[ -z "$CF" ] && CF="$(ssm "$SSM_PREFIX/web/distribution-domain-name")"
[ -z "$CF" ] && CF="$(out 60-api-edge cloudfront_distribution_domain_name)"

# apiEndpoint is whatever the deployer wired up — read it from the SPA's
# runtime-config.json (the control-plane skill's own discovery path), not a
# constructed/guessed URL.
API=""
[ -n "$CF" ] && API="$(curl -sS -m 15 "https://$CF/runtime-config.json" 2>/dev/null | jq -r '.apiEndpoint // empty' 2>/dev/null)"
[ -z "$API" ] && API="$(out 60-api-edge api_endpoint)"

GUARDRAIL="$(ssm "$SSM_PREFIX/bedrock/guardrail-id")"
[ -z "$GUARDRAIL" ] && GUARDRAIL="$(out 10-foundation guardrail_id)"

# ── Tier 1 — unauthenticated edge (network only) ────────────────────────────
echo; echo "Tier 1 — edge (HTTP)"
if [ -n "$CF" ]; then
  code=$(curl -sS -m 15 -o /dev/null -w '%{http_code}' "https://$CF/" 2>/dev/null)
  [ "$code" = "200" ] && ok "CloudFront root returns 200 ($CF)" || bad "CloudFront root returned $code (expected 200)"

  rc="$(curl -sS -m 15 "https://$CF/runtime-config.json" 2>/dev/null)"
  if echo "$rc" | jq -e '.region and .authority and .clientId and .apiEndpoint' >/dev/null 2>&1; then
    ok "runtime-config.json present with region/authority/clientId/apiEndpoint"
    echo "$rc" | jq -e '.mcpRuntimeArn' >/dev/null 2>&1 \
      && ok "runtime-config.json carries mcpRuntimeArn (v0.3.8 #1166)" \
      || bad "runtime-config.json missing mcpRuntimeArn (v0.3.8 wiring regression)"
  else
    bad "runtime-config.json missing or missing required keys"
  fi
else
  skip "CloudFront checks" "no cloudfront_distribution_domain_name output"
fi

if [ -n "$API" ]; then
  code=$(curl -sS -m 15 -o /dev/null -w '%{http_code}' "$API/health" 2>/dev/null)
  [ "$code" = "200" ] && ok "API /health returns 200 (mock health probe)" || bad "API /health returned $code (expected 200)"

  # An authenticated route must be guarded (401/403), never an unmapped 501 or a broken 5xx.
  code=$(curl -sS -m 15 -o /dev/null -w '%{http_code}' "$API/namespaces" 2>/dev/null)
  case "$code" in
    401|403) ok "API /namespaces is auth-guarded ($code), not stubbed/broken" ;;
    501)     bad "API /namespaces returned 501 (path unwired — stub fallback)" ;;
    5*)      bad "API /namespaces returned $code (handler broken)" ;;
    *)       bad "API /namespaces returned $code (expected 401/403)" ;;
  esac
else
  skip "API edge checks" "no api_endpoint output"
fi

# ── Tier 2 — AWS resource state (needs read creds) ──────────────────────────
echo; echo "Tier 2 — infra state (AWS)"
if ! aws sts get-caller-identity --region "$REGION" >/dev/null 2>&1; then
  skip "all Tier 2 checks" "no usable AWS credentials for $REGION"
else
  # Guardrail READY
  if [ -n "$GUARDRAIL" ]; then
    st=$(aws bedrock get-guardrail --guardrail-identifier "$GUARDRAIL" --region "$REGION" --query status --output text 2>/dev/null)
    [ "$st" = "READY" ] && ok "Bedrock guardrail $GUARDRAIL is READY" || bad "guardrail status=$st (expected READY)"
  else skip "guardrail check" "no guardrail_id output"; fi

  # AOSS collection ACTIVE
  st=$(aws opensearchserverless list-collections --region "$REGION" \
        --query "collectionSummaries[?starts_with(name, '$PREFIX')].status | [0]" --output text 2>/dev/null)
  [ "$st" = "ACTIVE" ] && ok "OpenSearch Serverless collection is ACTIVE" || bad "AOSS collection status=$st (expected ACTIVE)"

  # Neptune cluster available
  st=$(aws neptune describe-db-clusters --region "$REGION" \
        --query "DBClusters[?starts_with(DBClusterIdentifier, '$PREFIX')].Status | [0]" --output text 2>/dev/null)
  [ "$st" = "available" ] && ok "Neptune cluster is available" || bad "Neptune status=$st (expected available)"

  # ECS Fargate services: desired == running for every coa service
  CLUSTERS=$(aws ecs list-clusters --region "$REGION" --query 'clusterArns[]' --output text 2>/dev/null | tr '\t' '\n' | grep -i "$PREFIX" || true)
  if [ -z "$CLUSTERS" ]; then
    skip "ECS service checks" "no $PREFIX ECS clusters found"
  else
    for c in $CLUSTERS; do
      svcs=$(aws ecs list-services --cluster "$c" --region "$REGION" --query 'serviceArns[]' --output text 2>/dev/null)
      [ -z "$svcs" ] && continue
      badvc=$(aws ecs describe-services --cluster "$c" --services $svcs --region "$REGION" \
               --query 'length(services[?runningCount!=desiredCount])' --output text 2>/dev/null)
      name="${c##*/}"
      if [ "$badvc" = "0" ]; then ok "ECS $name: all services running==desired"; else bad "ECS $name: $badvc service(s) not at desired count"; fi
    done
  fi

  # Lambda health. NOTE: list-functions does NOT populate State/LastUpdateStatus
  # (only get-function-configuration does), so health must be checked per
  # function. A freshly-updated VPC Lambda may be Pending/InProgress briefly
  # after a deploy — that is transient, not a failure.
  FNS=$(aws lambda list-functions --region "$REGION" \
        --query "Functions[?starts_with(FunctionName, '$PREFIX')].FunctionName" --output text 2>/dev/null | tr '\t' '\n' | sed '/^$/d')
  if [ -z "$FNS" ]; then
    skip "Lambda checks" "no $PREFIX functions found"
  else
    FNCOUNT=$(printf '%s\n' "$FNS" | wc -l | tr -d ' ')
    lbad=0; lpending=0; lnames=""
    for fn in $FNS; do
      read -r st lus < <(aws lambda get-function-configuration --function-name "$fn" --region "$REGION" \
            --query '[State,LastUpdateStatus]' --output text 2>/dev/null)
      case "$st/$lus" in
        Active/Successful|Active/None|Active/) : ;;                    # healthy
        Pending/*|*/InProgress)               lpending=$((lpending+1)) ;;  # transient post-deploy
        *)                                     lbad=$((lbad+1)); lnames="$lnames $fn($st/$lus)" ;;
      esac
    done
    note=""; [ "$lpending" -gt 0 ] && note=" ($lpending settling)"
    if [ "$lbad" -eq 0 ]; then ok "all $FNCOUNT $PREFIX Lambda functions healthy$note"; else bad "$lbad/$FNCOUNT $PREFIX Lambda(s) unhealthy:$lnames"; fi
  fi
fi

# ── Tier 3 — authenticated end-to-end (opt-in: --auth) ──────────────────────
echo; echo "Tier 3 — authenticated end-to-end"
if [ "$WITH_AUTH" -ne 1 ]; then
  skip "end-to-end API call" "run with --auth (needs a Cognito web login via coa_login.py)"
elif [ -z "$API" ]; then
  skip "end-to-end API call" "no api_endpoint output"
else
  TOKEN="$(python3 "$REPO_ROOT/coa-skills/control-plane/scripts/coa_login.py" --client web --token-only 2>/dev/null)"
  if [ -z "$TOKEN" ]; then
    bad "could not obtain a web token (coa_login.py) — check the login flow"
  else
    code=$(curl -sS -m 20 -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "$API/namespaces" 2>/dev/null)
    [ "$code" = "200" ] && ok "authenticated GET /namespaces returns 200 (auth->handler->store OK)" || bad "authenticated GET /namespaces returned $code (expected 200)"
  fi
fi

# ── Summary ─────────────────────────────────────────────────────────────────
echo; echo "== $PASS passed, $FAIL failed, $SKIP skipped =="
[ "$FAIL" -eq 0 ] && { echo "Deployment smoke test PASSED."; exit 0; } || { echo "Deployment smoke test FAILED."; exit 1; }
