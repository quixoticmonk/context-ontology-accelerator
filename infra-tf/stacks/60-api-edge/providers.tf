# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

provider "aws" {
  region = var.region

  default_tags {
    tags = local.common_tags
  }
}

# us-east-1 alias for the web module (CloudFront cross-region reads)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = local.common_tags
  }
}

provider "awscc" {
  region = var.region
}
