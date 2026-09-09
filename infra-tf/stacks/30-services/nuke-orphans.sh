#!/usr/bin/env bash
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Delete the coa-dev-* DynamoDB tables, SQS queues, and S3 buckets that
# stack 30-services creates. Run when `make apply-30-services` fails with
# ResourceInUse / BucketAlreadyExists / QueueAlreadyExists on resources
# left behind by a previous partial apply or a prior CDK deploy.
#
# Does NOT touch Lambda functions, ECR, IAM, or Terraform state — those
# are typically what you want to keep between iterations.

set -euo pipefail

REGION="${REGION:-us-east-1}"
PREFIX="${PREFIX:-coa-dev-}"

echo "==> Region: $REGION   Prefix: $PREFIX"
aws sts get-caller-identity
echo

read -rp "Delete every ${PREFIX}* DDB table, SQS queue, and S3 bucket? [y/N] " confirm
[[ "$confirm" == "y" || "$confirm" == "Y" ]] || { echo "aborted"; exit 1; }

# ── DynamoDB tables ─────────────────────────────────────────────────
tables=$(aws dynamodb list-tables --region "$REGION" \
           --query "TableNames[?starts_with(@, \`${PREFIX}\`)]" --output text)
for t in $tables; do
  echo "==> ddb: $t"
  aws dynamodb delete-table --region "$REGION" --table-name "$t" >/dev/null
done
for t in $tables; do
  aws dynamodb wait table-not-exists --region "$REGION" --table-name "$t" 2>/dev/null || true
done

# ── SQS queues ──────────────────────────────────────────────────────
for url in $(aws sqs list-queues --region "$REGION" \
               --queue-name-prefix "$PREFIX" \
               --query 'QueueUrls[]' --output text 2>/dev/null); do
  echo "==> sqs: $url"
  aws sqs delete-queue --region "$REGION" --queue-url "$url"
done

# ── S3 buckets (empty versions + delete markers, then delete bucket) ─
for b in $(aws s3api list-buckets \
             --query "Buckets[?starts_with(Name, \`${PREFIX}\`)].Name" \
             --output text); do
  echo "==> s3: $b"
  for kind in Versions DeleteMarkers; do
    while : ; do
      batch=$(aws s3api list-object-versions --bucket "$b" \
                --query "{Objects:${kind}[].{Key:Key,VersionId:VersionId}}" \
                --output json 2>/dev/null || echo '{"Objects":null}')
      count=$(echo "$batch" | jq '.Objects | if . == null then 0 else length end')
      [[ "$count" -eq 0 ]] && break
      echo "  ...deleting $count $kind"
      echo "$batch" | jq '{Objects: (.Objects | map(select(.Key != null))), Quiet: true}' \
        | aws s3api delete-objects --bucket "$b" --delete file:///dev/stdin >/dev/null
    done
  done
  aws s3 rm "s3://$b" --recursive >/dev/null 2>&1 || true
  aws s3api delete-bucket --bucket "$b" --region "$REGION" 2>&1 | head -3 || true
done

echo
echo "==> Done. Retry: make apply-30-services"
