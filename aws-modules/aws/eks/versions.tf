terraform {
  required_providers {
    aws = {
      version               = ">= 5.25.0"
      configuration_aliases = [aws.main]
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
  }
}
