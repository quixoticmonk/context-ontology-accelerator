# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Module-level data sources shared across ddb.tf / s3.tf / sqs.tf /
# ecs.tf and the sub-turn-2/3/4 pipeline files.

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
