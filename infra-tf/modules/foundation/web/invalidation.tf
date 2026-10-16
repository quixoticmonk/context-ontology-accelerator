# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# CloudFront cache invalidation on content change.
# Fourth instance of the Reference R1 action-invoke pattern on this
# module (siblings: api_cors_patch.tf, cognito_callback_patch.tf, and
# services/sources/lakeformation_admin.tf).
#
# Without this, a deploy that changes index.html / assets / runtime-
# config.json serves stale content from edge POPs until the per-path
# TTL expires (24 h for the default cache behavior; 0 s for runtime-
# config.json via its ordered behavior). Users see "my change
# deployed but the site shows old content" and reach for
#   aws cloudfront create-invalidation --distribution-id <ID> --paths '/*'
# by hand after every apply.
#
# This block fires that command declaratively, from Terraform, triggered
# by any content change tracked by aws_s3_object resources above. The
# input hash on terraform_data is an opaque value TF compares; any
# change triggers the action.
#
# Cost: first 1000 invalidated paths/month are free from CloudFront;
# `["/*"]` counts as one path per invalidation. For typical dev deploy
# cadence (<= 10 deploys/day) this stays well under the free tier.
#
# Requires AWS provider >= 6.4 (invalidation action introduced then)
# and Terraform >= 1.14 (actions GA). Both pinned in terraform.tf.

action "aws_cloudfront_create_invalidation" "web" {
  config {
    distribution_id = aws_cloudfront_distribution.this.id
    paths           = ["/*"]
  }
}

resource "terraform_data" "invalidation_trigger" {
  # Fire whenever ANY website object's content hash changes, or the
  # runtime-config value changes. Both are plan-time-known values on
  # the aws_s3_object resources above, so there is no "known-after-
  # apply" problem that would require a two-phase apply.
  input = {
    object_etags        = { for key, obj in aws_s3_object.website : key => obj.etag }
    runtime_config_hash = md5(jsonencode(local.runtime_config))
  }

  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aws_cloudfront_create_invalidation.web]
    }
  }

  depends_on = [
    aws_s3_object.website,
    aws_s3_object.runtime_config,
    aws_cloudfront_distribution.this,
  ]
}
