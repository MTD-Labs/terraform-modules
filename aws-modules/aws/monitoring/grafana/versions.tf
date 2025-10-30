terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.25.0"
      configuration_aliases = [aws.main, aws.us_east_1]
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
      # configuration_aliases = [kubernetes.eks]
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
      # configuration_aliases = [helm.eks]
    }
  }
}
