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

  # Allowed CIDR sources (expecting lists for *_blocks vars)
  allowed_cidr_blocks = compact(concat(
    var.allow_vpc_cidr_block ? [var.vpc_cidr_block] : [""],
    var.allow_vpc_private_cidr_blocks ? var.vpc_private_cidr_blocks : [""],
    var.extra_allowed_cidr_blocks
  ))

  # RabbitMQ endpoints commonly needed on Amazon MQ:
  # - 5671: AMQP over TLS
  # - 443 : Web console (Amazon MQ exposes console via 443)
  # Add more if you enable MQTT/STOMP plugins: 8883 (MQTT TLS), 61614 (STOMP TLS)
  rabbitmq_inbound_ports = [5671, 443]
}

resource "random_password" "admin_password" {
  length           = 40
  special          = true
  min_special      = 5
  override_special = "!#$%^&*()-_=+[]{}<>:?"
  keepers = {
    pass_version = 1
  }
}

resource "random_password" "user_password" {
  for_each         = var.users
  length           = 32
  special          = true
  min_special      = 5
  override_special = "!#$%^&*()-_=+[]{}<>:?"
  keepers = {
    pass_version = 1
  }
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
  for_each = var.users

  name        = "${local.name}-${each.key}-password"
  value       = random_password.user_password[each.key].result
  description = "${local.name} ${each.key} user password"
  type        = "SecureString"
  key_id      = var.kms_ssm_key_arn
  tags        = local.tags
}

resource "aws_mq_broker" "amazon_mq" {
  broker_name                = local.name
  engine_type                = var.engine_type            # must be "RabbitMQ"
  engine_version             = var.engine_version         # e.g., "3.13.2" per-region support
  host_instance_type         = var.instance_type
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  deployment_mode            = var.deployment_mode
  publicly_accessible        = false

  security_groups = [aws_security_group.mq_security_group.id]

  # If SINGLE_INSTANCE use first subnet; otherwise pass all for ACTIVE_STANDBY_MULTI_AZ / CLUSTER_MULTI_AZ
  subnet_ids = var.deployment_mode == "SINGLE_INSTANCE" ? [var.vpc_subnets[0]] : var.vpc_subnets

  # Authentication (RabbitMQ supports SIMPLE only)
  authentication_strategy = var.authentication_strategy

  # Encryption
  encryption_options {
    kms_key_id        = var.kms_mq_key_arn
    use_aws_owned_key = var.kms_mq_key_arn == null
  }

  # Logging (RabbitMQ: only 'general' is supported; 'audit' is NOT supported)
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

  dynamic "user" {
    for_each = var.users
    content {
      username       = user.key
      password       = random_password.user_password[user.key].result
      groups         = user.value.groups
      console_access = try(user.value.console_access, false)
    }
  }

  tags = local.tags
}

resource "aws_security_group" "mq_security_group" {
  name        = "${local.name}-amazon-mq-security-group"
  description = "Security group for Amazon MQ (RabbitMQ) allowing access from private subnets"
  vpc_id      = var.vpc_id

  # Engine: RabbitMQ
  # Create ingress rules for each required port
  dynamic "ingress" {
    for_each = toset(local.rabbitmq_inbound_ports)
    content {
      from_port       = ingress.value
      to_port         = ingress.value
      protocol        = "tcp"
      cidr_blocks     = local.allowed_cidr_blocks
      security_groups = concat([var.bastion_security_group_id], var.additional_security_group_ids)
    }
  }

  # Egress: allow all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}
