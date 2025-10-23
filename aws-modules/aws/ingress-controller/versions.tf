terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 5.25.0"
      configuration_aliases = [aws.main, aws.us_east_1]
    }
  }
}
