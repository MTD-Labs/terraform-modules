data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

data "aws_security_group" "default" {
  name   = "default"
  vpc_id = module.vpc.vpc_id
}

locals {
  common_tags = {
    Env        = var.env
    tf-managed = true
    tf-module  = "aws/vpc"
  }

  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"

  name = "${var.env}-vpc"
  cidr = var.vpc_cidr
  azs  = local.azs

  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  ### If needed, DB subnets can be separated
  # elasticache_subnets           = var.elasticache_subnets
  # elasticache_subnet_group_name = "${var.env}-elasticache-subnet-group"
  database_subnets           = var.database_subnets
  database_subnet_group_name = "${var.env}-database-subnet-group"

  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support
  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway

  tags                = local.common_tags
  public_subnet_tags  = local.common_tags
  private_subnet_tags = local.common_tags
}

module "vpc_endpoints" {
  source             = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version            = "5.1.2"
  vpc_id             = module.vpc.vpc_id
  security_group_ids = [data.aws_security_group.default.id]

  endpoints = merge(
    {
      s3 = {
        service = "s3"
        tags    = { Name = "s3-vpc-endpoint" }
      },
      ecs_telemetry = {
        create              = false
        service             = "ecs-telemetry"
        private_dns_enabled = true
        subnet_ids          = module.vpc.private_subnets
      }
    },
    var.ecs_enabled ? {
      ecs = {
        service             = "ecs"
        private_dns_enabled = true
        subnet_ids          = module.vpc.private_subnets
        tags                = { Name = "ecs-vpc-endpoint" }
      }
    } : {},
    var.postgres_enabled ? {
      rds = {
        service             = "rds"
        private_dns_enabled = true
        subnet_ids          = module.vpc.private_subnets
        security_group_ids  = [aws_security_group.rds.id]
        tags                = { Name = "rds-vpc-endpoint" }
      }
    } : {}
  )
}

resource "aws_security_group" "rds" {
  name_prefix = "${var.env}-rds"
  description = "Allow PostgreSQL inbound traffic for VPC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "TLS from VPC"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  tags = local.common_tags
}
