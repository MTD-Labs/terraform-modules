########################################
# main.tf — Amazon MQ for RabbitMQ only
########################################

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  name = var.name == "" ? "${var.env}-amq" : "${var.env}-amq-${var.name}"
  tags = merge({
    Name       = local.name
    Env        = var.env
    tf-managed = true
  }, var.tags)
    allowed_cidr_blocks = compact(concat(
      var.allow_vpc_private_cidr_blocks ? var.vpc_private_cidr_blocks : [],
      var.extra_allowed_cidr_blocks != "" ? [var.extra_allowed_cidr_blocks] : []
    ))
}

# Admin password (safe: A–Z, a–z, 0–9 only)
resource "random_password" "admin_password" {
  length      = 24
  special     = false # no punctuation at all
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  keepers     = { pass_version = 1 } # bump to rotate
}

resource "random_password" "user_password" {
  for_each    = var.users
  length      = 24
  special     = false
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  keepers     = { pass_version = 1 } # bump to rotate
}

resource "aws_ssm_parameter" "admin_password" {
  name        = "${local.name}-admin-password"
  value       = random_password.admin_password.result
  description = "${local.name} admin password"
  type        = "SecureString"
  key_id      = var.kms_ssm_key_arn
  tags        = local.tags
}

resource "aws_ssm_parameter" "user_passwords" {
  for_each    = var.users
  name        = "${local.name}-${each.key}-password"
  value       = random_password.user_password[each.key].result
  description = "${local.name} ${each.key} user password"
  type        = "SecureString"
  key_id      = var.kms_ssm_key_arn
  tags        = local.tags
}

# --- Security Group (RabbitMQ ports only) ---
resource "aws_security_group" "mq_security_group" {
  name        = "${local.name}-amazon-mq-sg"
  description = "Security group for Amazon MQ (RabbitMQ)"
  vpc_id      = var.vpc_id
  tags        = local.tags


  # Web console via 443 on Amazon MQ for RabbitMQ
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["172.31.0.0/16"]
  }

  ingress {
    from_port       = 5671
    to_port         = 5671
    protocol        = "tcp"
    cidr_blocks     = local.allowed_cidr_blocks
    security_groups = var.bastion_security_group_id != "" ? [var.bastion_security_group_id] : []
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Amazon MQ Broker (RabbitMQ) ---
resource "aws_mq_broker" "amazon_mq" {
  broker_name                = local.name
  engine_type                = var.engine_type    # must be "RabbitMQ"
  engine_version             = var.engine_version # e.g., "3.13.2" if supported in your region
  host_instance_type         = var.instance_type
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  deployment_mode            = var.deployment_mode # e.g., "SINGLE_INSTANCE" or "CLUSTER_MULTI_AZ"
  publicly_accessible        = false
  security_groups            = [aws_security_group.mq_security_group.id]

  # Provide one or more subnets as required by your deployment mode
  subnet_ids = var.vpc_subnets

  # RabbitMQ supports SIMPLE only
  authentication_strategy = var.authentication_strategy

  # Encryption
  encryption_options {
    kms_key_id        = var.kms_mq_key_arn
    use_aws_owned_key = var.kms_mq_key_arn == null || var.kms_mq_key_arn == "" ? true : false
  }

  # Logging (RabbitMQ: only 'general' is supported)
  logs {
    general = var.enable_general_logging
  }

  # Maintenance window
  maintenance_window_start_time {
    day_of_week = var.maintenance_day_of_week
    time_of_day = var.maintenance_time_of_day
    time_zone   = var.maintenance_time_zone
  }

  # Users
  user {
    username       = var.admin_username
    password       = random_password.admin_password.result
    console_access = true
    groups         = ["admin"]
  }

  # dynamic "user" {
  #   for_each = var.users
  #   content {
  #     username       = user.key
  #     password       = random_password.user_password[user.key].result
  #     groups         = user.value.groups
  #     console_access = try(user.value.console_access, false)
  #   }
  # }

  tags = local.tags
}
