terraform {
  required_version = ">= 1.5"

  # backend "s3" {}

  required_providers {
    aws    = ">= 4.40.0"
    local  = ">= 2.2.3"
    random = ">= 3.4.3"

    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = "= 1.18.0"
    }
  }
}

# provider "aws" {
#   region = var.region
# }

# provider "postgresql" {
#   scheme    = "awspostgres"
#   superuser = false

#   host     = module.aurora.cluster_endpoint
#   username = module.aurora.cluster_master_username
#   port     = module.aurora.cluster_port
#   password = module.aurora.cluster_master_password

# }
