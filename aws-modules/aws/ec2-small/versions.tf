terraform {
  required_version = ">= 1.5"

  # backend "s3" {}

  required_providers {
    aws      = ">= 4.38.0"
    local    = ">= 2.2.2"
    null     = ">= 3.1.1"
    template = ">= 2.2.0"
    random   = ">= 3.4.3"
    cloudflare = ">= 4.43"

  }
}

# provider "aws" {
#   region = var.region
# }
