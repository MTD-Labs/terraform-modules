terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      version               = ">= 5.25.0"
      configuration_aliases = [aws.main, aws.us_east_1]
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}
