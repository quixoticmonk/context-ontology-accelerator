# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_version = ">= 1.13"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    awscc = {
      # DataZone resources missing from `aws`: project_profile,
      # project_membership, owner. Every other DataZone resource this
      # module creates uses the native aws provider.
      source  = "hashicorp/awscc"
      version = "~> 1.100"
    }
    time = {
      # Used to bridge DataZone's eventual-consistency window between
      # domain creation (which auto-registers the caller's user profile)
      # and add-entity-owner (which needs that profile discoverable).
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
    external = {
      # Used to resolve the caller's auto-created DataZone user profile
      # UUID (needed for AddEntityOwner — role ARN alone does not work).
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}
