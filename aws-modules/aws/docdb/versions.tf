terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      version               = ">= 5.25.0"
      configuration_aliases = [aws.main]
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.4.3"
    }
  }
}