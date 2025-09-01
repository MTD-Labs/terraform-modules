terraform {
  required_version = ">= 1.5"

  #   backend "s3" {}

  required_providers {
    aws   = ">= 4.38.0"
    local = ">= 2.2.2"
  }
}

# provider "aws" {
#   region = var.region
# }
