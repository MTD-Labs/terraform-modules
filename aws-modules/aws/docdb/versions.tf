terraform {
  required_version = ">= 1.5"

  required_providers {
    aws    = ">= 4.40.0"
    random = ">= 3.4.3"
    local  = ">= 2.2.3"
  }
}

# provider "aws" {
#   region = var.region
# }
