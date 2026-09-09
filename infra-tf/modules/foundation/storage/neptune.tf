# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Neptune graph database. IAM authentication enabled (SigV4 signing);
# storage encrypted with the AWS-owned key; 7-day automated backups.
# deletion_protection is on only in prod. Removal policy is DESTROY in
# all environments (matches the CDK applyRemovalPolicy(DESTROY)) — the
# cluster/instance are recreated on teardown, so no prevent_destroy.

resource "aws_neptune_subnet_group" "this" {
  name        = "${var.name_prefix}-neptune-subnet-group"
  description = "Private subnets for the SemanticContext Neptune cluster"
  subnet_ids  = var.private_subnet_ids

  tags = { Component = var.component }
}

resource "aws_neptune_cluster" "this" {
  cluster_identifier                  = "${var.name_prefix}-neptune"
  engine                              = "neptune"
  engine_version                      = "1.4.7.0"
  neptune_subnet_group_name           = aws_neptune_subnet_group.this.name
  vpc_security_group_ids              = [var.neptune_security_group_id]
  iam_database_authentication_enabled = true
  storage_encrypted                   = true
  deletion_protection                 = local.is_prod
  backup_retention_period             = 7
  apply_immediately                   = true
  skip_final_snapshot                 = true

  tags = { Component = var.component }
}

resource "aws_neptune_cluster_instance" "this" {
  cluster_identifier = aws_neptune_cluster.this.id
  identifier         = "${var.name_prefix}-neptune-primary"
  instance_class     = "db.r8g.large"
  engine             = "neptune"
  apply_immediately  = true

  tags = { Component = var.component }
}
