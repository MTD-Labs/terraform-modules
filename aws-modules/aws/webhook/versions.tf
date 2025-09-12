terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      version               = ">= 5.25.0"
      configuration_aliases = [aws.main, aws.us_east_1]
    }
    archive = { source = "hashicorp/archive", version = ">= 2.4.0" }
  }
}
