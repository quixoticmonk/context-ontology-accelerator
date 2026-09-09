# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

terraform {
  required_version = ">= 1.13"

  required_providers {
    archive = { source = "hashicorp/archive", version = "~> 2.7" }
    aws     = { source = "hashicorp/aws", version = "~> 6.0" }
    awscc   = { source = "hashicorp/awscc", version = "~> 1.100" }
    null     = { source = "hashicorp/null", version = "~> 3.2" }
    random   = { source = "hashicorp/random", version = "~> 3.6" }
    time     = { source = "hashicorp/time", version = "~> 0.12" }
    external = { source = "hashicorp/external", version = "~> 2.3" }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}
