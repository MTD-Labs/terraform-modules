terraform {
  required_version = ">= 1.5"

  # backend "s3" {}

  required_providers {
    aws      = ">= 4.39.0"
    local    = ">= 2.2.2"
    null     = ">= 3.1.1"
    template = ">= 2.2.0"
    random   = ">= 3.4.3"
  }
}

# provider "aws" {
#   region = var.region
# }
