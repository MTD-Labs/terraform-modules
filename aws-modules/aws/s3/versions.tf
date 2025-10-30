terraform {
  required_version = ">= 1.5"

  #   backend "s3" {}

  required_providers {
    aws = {
      version               = ">= 5.25.0"
      configuration_aliases = [aws.main]
    }
    local = ">= 2.2.2"
  }
}

# provider "aws" {
#   region = var.region
# }
