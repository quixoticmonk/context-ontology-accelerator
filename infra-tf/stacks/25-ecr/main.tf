# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Stack 25 — ECR repositories for every service that ships a container
# image. Runs before `make build` so image pushes have a valid target.
# Downstream stacks (30, 40, 60) read the repo URL/ARN from SSM.

resource "aws_ecr_repository" "this" {
  for_each = local.repositories

  name                 = each.value
  image_tag_mutability = "IMMUTABLE"
  force_delete         = local.force_delete

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }
}

resource "aws_ssm_parameter" "url" {
  for_each = aws_ecr_repository.this

  name  = "${local.ssm_prefix}/ecr/${replace(each.key, "_", "-")}/url"
  type  = "String"
  value = each.value.repository_url
}

resource "aws_ssm_parameter" "arn" {
  for_each = aws_ecr_repository.this

  name  = "${local.ssm_prefix}/ecr/${replace(each.key, "_", "-")}/arn"
  type  = "String"
  value = each.value.arn
}
