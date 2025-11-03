data "aws_availability_zones" "available" {}

locals {
  name = var.name == "" ? "${var.env}-redis" : "${var.env}-redis-${var.name}"
  tags = merge({
    Name       = local.name
    env        = var.env
    tf-managed = true
    tf-module  = "aws/redis"
  }, var.tags)
}

locals {
  allowed_cidr_blocks = compact(concat(
    var.allow_vpc_cidr_block ? [var.vpc_cidr_block] : [""],
    var.allow_vpc_private_cidr_blocks ? var.vpc_private_cidr_blocks : [""],
    [var.extra_allowed_cidr_blocks]
  ))
}
resource "random_password" "auth_token" {
  length      = 24
  special     = false # no punctuation at all
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  keepers     = { pass_version = 1 } # bump to rotate
}

resource "aws_ssm_parameter" "auth_token" {
  name        = "${local.name}-auth-token"
  value       = random_password.auth_token.result
  description = "${local.name} auth token"
  type        = "SecureString"
  key_id      = var.kms_ssm_key_arn
  tags        = local.tags
}

module "redis" {
  source                     = "cloudposse/elasticache-redis/aws"
  version                    = "2.0.0"
  name                       = local.name
  engine_version             = var.engine_version
  family                     = var.family
  cluster_size               = var.cluster_size
  instance_type              = var.instance_type
  apply_immediately          = false
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.auth_token.result

  availability_zones            = data.aws_availability_zones.available.names
  vpc_id                        = var.vpc_id
  subnets                       = var.vpc_subnets
  create_security_group         = true
  associated_security_group_ids = []
  # elasticache_subnet_group_name = var.vpc_subnet_group_name

  additional_security_group_rules = [
    {
      type        = "ingress"
      from_port   = 6379
      to_port     = 6379
      protocol    = "tcp"
      cidr_blocks = local.allowed_cidr_blocks
    }
  ]

  cluster_mode_enabled                 = var.cluster_mode_enabled
  cluster_mode_num_node_groups         = var.cluster_mode_num_node_groups
  cluster_mode_replicas_per_node_group = var.cluster_mode_replicas_per_node_group
  replication_group_id                 = substr(local.name, 0, min(length(local.name), 20)) # needs to be <20 characters long
  automatic_failover_enabled           = var.automatic_failover_enabled
  snapshot_retention_limit             = var.snapshot_retention_limit
  snapshot_window                      = var.snapshot_window
  cloudwatch_metric_alarms_enabled     = true

  #workaround for auth issue
  user_group_ids = null

  #global parameter used in all instances
  parameter = [
    {
      name  = "maxmemory-policy"
      value = "volatile-lfu"
    }
  ]

  tags = local.tags
}
