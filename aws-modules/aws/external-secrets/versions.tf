terraform {
  required_providers {

    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.25.0"
      configuration_aliases = [aws.main, aws.us_east_1]
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }

    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }

    time = {
      source  = "hashicorp/time"
      version = ">= 0.9.0"
    }

  }
}