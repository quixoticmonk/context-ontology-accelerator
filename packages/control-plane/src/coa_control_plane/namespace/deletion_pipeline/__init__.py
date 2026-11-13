# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Namespace deletion Step Functions pipeline — Lambda task handlers.

Each module here is invoked as a Step Functions ``LambdaInvoke`` task. The
state machine definition lives in Terraform
(``infra-tf/modules/services/namespace/deletion_pipeline.tf``).
"""
