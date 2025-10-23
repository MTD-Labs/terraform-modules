data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  name = var.name == "" ? "${var.env}-docdb" : "${var.env}-docdb-${var.name}"
  tags = merge(
    {
      Name       = local.name
      Env        = var.env
      tf-managed = true
    },
    var.tags != null ? var.tags : {}
  )
}

# Build allowed CIDR list similar to Postgres module
locals {
  allowed_cidr_blocks = compact(concat(
    var.allow_vpc_cidr_block ? [var.vpc_cidr_block] : [""],
    var.allow_vpc_private_cidr_blocks ? var.vpc_private_cidr_blocks : [""],
    [var.extra_allowed_cidr_blocks]
  ))
}

# Master password -> stored to SSM (encrypted with provided KMS key)
resource "random_password" "master" {
  length           = 40
  special          = true
  min_special      = 5
  override_special = "!#$%^&*()-_=+[]{}<>:?"
  keepers = {
    pass_version = 1
  }
}

resource "aws_ssm_parameter" "master_password" {
  name        = "${local.name}-master-password"
  description = "${local.name} master password"
  type        = "SecureString"
  key_id      = var.kms_ssm_key_arn
  value       = random_password.master.result
  tags        = local.tags
}

# Security Group that allows 27017 from allowed CIDRs and bastion SG
resource "aws_security_group" "docdb_sg" {
  name        = "${local.name}-sg"
  description = "Security group for DocumentDB"
  vpc_id      = var.vpc_id
  tags        = local.tags

  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    cidr_blocks     = local.allowed_cidr_blocks
    security_groups = [var.bastion_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Optional: create a cluster parameter group from the provided map
resource "aws_docdb_cluster_parameter_group" "this" {
  name        = "${local.name}-cluster-params"
  family      = var.family
  description = "${local.name} cluster parameter group"
  tags        = local.tags

  dynamic "parameter" {
    for_each = var.docdb_cluster_parameters
    content {
      name  = parameter.key
      value = parameter.value
    }
  }
}

# NOTE: we assume you already have a DB subnet group name (same pattern as your Postgres module).
# If you want this module to optionally create it, add a toggle + aws_docdb_subnet_group resource.

resource "aws_docdb_cluster" "this" {
  cluster_identifier                 = local.name
  engine                             = "docdb"
  engine_version                     = var.engine_version
  master_username                    = var.master_username
  master_password                    = random_password.master.result
  db_subnet_group_name               = var.vpc_subnet_group_name
  vpc_security_group_ids             = [aws_security_group.docdb_sg.id]
  storage_encrypted                  = true
  kms_key_id                         = var.kms_key_id
  apply_immediately                  = false
  backup_retention_period            = var.backup_retention_period
  preferred_backup_window            = var.preferred_backup_window
  preferred_maintenance_window       = var.preferred_maintenance_window
  deletion_protection                = var.deletion_protection
  skip_final_snapshot                = var.skip_final_snapshot
  enabled_cloudwatch_logs_exports    = var.enabled_cloudwatch_logs_exports
  port                               = 27017
  # By default DocumentDB requires TLS on 27017.
  # Parameter group attach:
  db_cluster_parameter_group_name    = aws_docdb_cluster_parameter_group.this.name

  tags = local.tags
}

resource "aws_docdb_cluster_instance" "this" {
  count                     = var.instances_count
  identifier                = "${local.name}-${count.index + 1}"
  cluster_identifier        = aws_docdb_cluster.this.id
  instance_class            = var.instance_class
  apply_immediately         = false
  promotion_tier            = count.index + 1
  auto_minor_version_upgrade = false
  tags                      = local.tags
}
