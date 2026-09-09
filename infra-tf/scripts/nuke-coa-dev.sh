#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Delete every coa-dev-* resource this repo's Terraform stacks manage,
# and wipe every stacks/*/terraform.tfstate*. Use before re-applying from
# scratch when previous CDK or partial-TF runs left orphans behind.
#
# Covers, in order of dependency:
#   - DataZone domain(s) named coa-dev-smus-catalog
#   - Lambda functions (coa-dev-*)
#   - ECR repositories (coa-dev-*)
#   - S3 buckets (coa-dev-*)
#   - DynamoDB tables (coa-dev-*)
#   - SQS queues (coa-dev-*)
#   - AOSS access policies (data + network) named coa-dev-*
#   - SSM parameters under /coa
#   - IAM roles + customer-managed policies (coa-dev-*)
#   - Every stacks/*/terraform.tfstate*
#
# Assumes AWS_PROFILE points at the intended account. Confirm with
#   aws sts get-caller-identity
# before running.

set -euo pipefail

REGION="${REGION:-us-east-1}"
DOMAIN_NAME="${DOMAIN_NAME:-coa-dev-smus-catalog}"
PREFIX="${PREFIX:-coa-dev-}"
SSM_ROOT="${SSM_ROOT:-/coa}"

echo "==> Region:       $REGION"
echo "==> Domain name:  $DOMAIN_NAME"
echo "==> Prefix:       $PREFIX"
echo "==> SSM root:     $SSM_ROOT"
aws sts get-caller-identity
echo

read -rp "This will DELETE every ${PREFIX}* AWS resource this repo manages AND every stacks/*/terraform.tfstate. Continue? [y/N] " confirm
[[ "$confirm" == "y" || "$confirm" == "Y" ]] || { echo "aborted"; exit 1; }

# ── 1. DataZone domain(s) matching the name ─────────────────────────
for id in $(aws datazone list-domains --region "$REGION" \
              --query "items[?name==\`${DOMAIN_NAME}\`].id" --output text); do
  echo "==> datazone domain: $id"
  aws datazone delete-domain --identifier "$id" --skip-deletion-check --region "$REGION"
done
while true; do
  remaining=$(aws datazone list-domains --region "$REGION" \
                --query "items[?name==\`${DOMAIN_NAME}\`].id" --output text)
  [[ -z "$remaining" ]] && break
  echo "  ...still deleting: $remaining"; sleep 15
done

# ── 2. Lambda functions ─────────────────────────────────────────────
for fn in $(aws lambda list-functions --region "$REGION" \
              --query "Functions[?starts_with(FunctionName, \`${PREFIX}\`)].FunctionName" \
              --output text); do
  echo "==> lambda: $fn"
  aws lambda delete-function --function-name "$fn" --region "$REGION"
done

# ── 3. ECR repositories ─────────────────────────────────────────────
for repo in $(aws ecr describe-repositories --region "$REGION" \
                --query "repositories[?starts_with(repositoryName, \`${PREFIX}\`)].repositoryName" \
                --output text); do
  echo "==> ecr: $repo"
  aws ecr delete-repository --region "$REGION" --repository-name "$repo" --force >/dev/null
done

# ── 4. S3 buckets (empty first, then delete) ────────────────────────
for b in $(aws s3api list-buckets \
             --query "Buckets[?starts_with(Name, \`${PREFIX}\`)].Name" \
             --output text); do
  echo "==> s3: $b"
  # Handle versioned buckets: delete all versions + delete markers
  for kind in Versions DeleteMarkers; do
    while : ; do
      batch=$(aws s3api list-object-versions --bucket "$b" \
                --query "{Objects:${kind}[].{Key:Key,VersionId:VersionId}}" \
                --output json 2>/dev/null)
      count=$(echo "$batch" | jq '.Objects | if . == null then 0 else length end')
      [[ "$count" -eq 0 ]] && break
      echo "  ...deleting $count $kind"
      echo "$batch" | jq '{Objects: (.Objects | map(select(.Key != null))), Quiet: true}' \
        | aws s3api delete-objects --bucket "$b" --delete "file:///dev/stdin" >/dev/null
    done
  done
  aws s3 rm "s3://$b" --recursive >/dev/null 2>&1 || true
  aws s3api delete-bucket --bucket "$b" --region "$REGION" 2>&1 | head -3 || true
done

# ── 5. DynamoDB tables ──────────────────────────────────────────────
for t in $(aws dynamodb list-tables --region "$REGION" \
             --query "TableNames[?starts_with(@, \`${PREFIX}\`)]" \
             --output text); do
  echo "==> ddb: $t"
  aws dynamodb delete-table --region "$REGION" --table-name "$t" >/dev/null
done
# Wait for deletes
for t in $(aws dynamodb list-tables --region "$REGION" \
             --query "TableNames[?starts_with(@, \`${PREFIX}\`)]" \
             --output text); do
  aws dynamodb wait table-not-exists --region "$REGION" --table-name "$t" 2>/dev/null || true
done

# ── 6. SQS queues ───────────────────────────────────────────────────
# AWS CLI returns the literal string "None" (not an empty result) when
# no queues match, so filter that out too.
for url in $(aws sqs list-queues --region "$REGION" \
               --queue-name-prefix "$PREFIX" \
               --query 'QueueUrls[]' --output text 2>/dev/null); do
  [[ -z "$url" || "$url" == "None" ]] && continue
  echo "==> sqs: $url"
  aws sqs delete-queue --region "$REGION" --queue-url "$url"
done

# ── 7. AOSS access policies (data + network) ────────────────────────
for type in data network; do
  for name in $(aws opensearchserverless list-access-policies \
                  --type "$type" --region "$REGION" \
                  --query "accessPolicySummaries[?starts_with(name, \`${PREFIX}\`)].name" \
                  --output text 2>/dev/null); do
    echo "==> aoss policy ($type): $name"
    aws opensearchserverless delete-access-policy \
      --name "$name" --type "$type" --region "$REGION"
  done
done

# ── 8. SSM parameters under $SSM_ROOT ───────────────────────────────
# Batched to survive very large trees.
next_token=""
while : ; do
  args=(--region "$REGION" --path "$SSM_ROOT" --recursive --max-results 10 \
        --query 'Parameters[].Name' --output text)
  [[ -n "$next_token" ]] && args+=(--starting-token "$next_token")
  names=$(aws ssm get-parameters-by-path "${args[@]}" 2>/dev/null || true)
  [[ -z "$names" ]] && break
  for n in $names; do
    echo "==> ssm: $n"
    aws ssm delete-parameter --region "$REGION" --name "$n" 2>/dev/null || true
  done
  # aws CLI's built-in pagination handles all pages when we don't pass a
  # starting token; simplest: loop until no more results.
  break
done

# ── 9. IAM roles ────────────────────────────────────────────────────
for role in $(aws iam list-roles \
                --query "Roles[?starts_with(RoleName, \`${PREFIX}\`)].RoleName" \
                --output text); do
  echo "==> role: $role"
  for p in $(aws iam list-attached-role-policies --role-name "$role" \
               --query 'AttachedPolicies[].PolicyArn' --output text); do
    aws iam detach-role-policy --role-name "$role" --policy-arn "$p"
  done
  for p in $(aws iam list-role-policies --role-name "$role" \
               --query 'PolicyNames[]' --output text); do
    aws iam delete-role-policy --role-name "$role" --policy-name "$p"
  done
  for ip in $(aws iam list-instance-profiles-for-role --role-name "$role" \
                --query 'InstanceProfiles[].InstanceProfileName' \
                --output text 2>/dev/null); do
    aws iam remove-role-from-instance-profile --instance-profile-name "$ip" --role-name "$role"
  done
  aws iam delete-role --role-name "$role"
done

# ── 10. IAM customer-managed policies ───────────────────────────────
for arn in $(aws iam list-policies --scope Local \
               --query "Policies[?starts_with(PolicyName, \`${PREFIX}\`)].Arn" \
               --output text); do
  echo "==> policy: $arn"
  for r in $(aws iam list-entities-for-policy --policy-arn "$arn" \
               --query 'PolicyRoles[].RoleName' --output text); do
    aws iam detach-role-policy --role-name "$r" --policy-arn "$arn"
  done
  for u in $(aws iam list-entities-for-policy --policy-arn "$arn" \
               --query 'PolicyUsers[].UserName' --output text); do
    aws iam detach-user-policy --user-name "$u" --policy-arn "$arn"
  done
  for g in $(aws iam list-entities-for-policy --policy-arn "$arn" \
               --query 'PolicyGroups[].GroupName' --output text); do
    aws iam detach-group-policy --group-name "$g" --policy-arn "$arn"
  done
  for v in $(aws iam list-policy-versions --policy-arn "$arn" \
               --query 'Versions[?IsDefaultVersion==`false`].VersionId' \
               --output text); do
    aws iam delete-policy-version --policy-arn "$arn" --version-id "$v"
  done
  aws iam delete-policy --policy-arn "$arn"
done

# ── 11. Local Terraform state across every stack ────────────────────
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stacks_dir="$(cd "$here/../stacks" && pwd)"
for d in "$stacks_dir"/*/; do
  rm -f "$d"terraform.tfstate "$d"terraform.tfstate.backup
done
echo "==> Wiped every stacks/*/terraform.tfstate*"

echo
echo "==> Clean. Now run:"
echo "    make apply-00-network apply-10-foundation apply-20-namespace apply-25-ecr"
echo "    make build"
echo "    make apply-30-services apply-40-sources apply-60-api-edge apply-50-agentcore apply-70-observability"
