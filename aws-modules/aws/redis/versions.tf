terraform {
  required_version = ">= 1.5"

  # backend "s3" {}

  required_providers {
    aws    = ">= 4.40.0"
    local  = ">= 2.2.3"
    random = ">= 3.4.3"
  }
}

# provider "aws" {
#   region = var.region
# }
