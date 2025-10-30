data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  name = var.name == "" ? "${var.env}-docdb" : "${var.env}-docdb-${var.name}"
  tags = merge(
    var.tags,
    {
      Name       = local.name
      Env        = var.env
      tf-managed = true
    }
  )
}

locals {
  allowed_cidr_blocks = compact(concat(
    var.allow_vpc_private_cidr_blocks ? var.vpc_private_cidr_blocks : [],
    var.extra_allowed_cidr_blocks != "" ? [var.extra_allowed_cidr_blocks] : []
  ))
}

# Generate master password
resource "random_password" "master" {
  length           = 40
  special          = true
  min_special      = 5
  override_special = "!#$%^&*()-_=+[]{}<>:?"
  keepers = {
    pass_version = 1
  }
}

# Store master password in SSM Parameter Store
resource "aws_ssm_parameter" "master_password" {
  name        = "${local.name}-master-password"
  value       = random_password.master.result
  description = "${local.name} master password"
  type        = "SecureString"
  key_id      = var.kms_ssm_key_arn
  tags        = local.tags
}

# DocumentDB Subnet Group
resource "aws_docdb_subnet_group" "docdb" {
  name        = "${local.name}-subnet-group"
  subnet_ids  = var.vpc_subnets
  description = "Subnet group for ${local.name}"
  tags        = local.tags
}

# DocumentDB Cluster Parameter Group
resource "aws_docdb_cluster_parameter_group" "docdb" {
  family      = var.family
  name        = "${local.name}-cluster-parameter-group"
  description = "DocumentDB cluster parameter group for ${local.name}"

  dynamic "parameter" {
    for_each = var.cluster_parameters
    content {
      name  = parameter.key
      value = parameter.value
    }
  }

  tags = local.tags
}

# Security Group for DocumentDB
resource "aws_security_group" "docdb_security_group" {
  name        = "${local.name}-security-group"
  description = "Security group for DocumentDB allowing access from private subnets"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 27017
    to_port         = 27017
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

  tags = local.tags
}

# DocumentDB Cluster
resource "aws_docdb_cluster" "docdb" {
  cluster_identifier              = local.name
  engine                          = "docdb"
  engine_version                  = var.engine_version
  master_username                 = var.master_username
  master_password                 = random_password.master.result
  db_subnet_group_name            = aws_docdb_subnet_group.docdb.name
  db_cluster_parameter_group_name = aws_docdb_cluster_parameter_group.docdb.name
  vpc_security_group_ids          = [aws_security_group.docdb_security_group.id]

  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window

  storage_encrypted = true
  kms_key_id        = var.kms_key_arn != "" ? var.kms_key_arn : null

  apply_immediately         = var.apply_immediately
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${local.name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  deletion_protection = var.deletion_protection

  tags = local.tags
}

# DocumentDB Cluster Instances
resource "aws_docdb_cluster_instance" "docdb_instances" {
  count              = var.instance_count
  identifier         = "${local.name}-instance-${count.index + 1}"
  cluster_identifier = aws_docdb_cluster.docdb.id
  instance_class     = var.instance_class

  auto_minor_version_upgrade   = var.auto_minor_version_upgrade
  preferred_maintenance_window = var.preferred_maintenance_window

  promotion_tier = count.index

  tags = merge(
    local.tags,
    {
      Name = "${local.name}-instance-${count.index + 1}"
    }
  )
}