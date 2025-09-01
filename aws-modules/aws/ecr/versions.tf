terraform {
  required_version = ">= 1.5"

  #   backend "s3" {}

  required_providers {
    aws = {
      version               = ">= 5.25.0"
      configuration_aliases = [aws.main, aws.us_east_1]
    }
  }
}

# provider "aws" {
#   region = var.region
# }

# provider "aws" {
#   alias  = "us_east_1"
#   region = "us-east-1"
# }