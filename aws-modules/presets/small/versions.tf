terraform {
  required_version = ">= 1.5"

  # backend "s3" {}

  required_providers {
    aws = {
      version               = ">= 5.25.0"
      configuration_aliases = [aws.main, aws.us_east_1]
    }

    local      = ">= 2.2.2"
    null       = ">= 3.1.1"
    template   = ">= 2.2.0"
    random     = ">= 3.4.3"
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
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