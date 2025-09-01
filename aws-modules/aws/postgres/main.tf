data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  name = var.name == "" ? "${var.env}-db" : "${var.env}-db-${var.name}"
  tags = {
    Name       = local.name
    Env        = var.env
    tf-managed = true
  }
}

locals {
  allowed_cidr_blocks = compact(concat(
    var.allow_vpc_cidr_block ? [var.vpc_cidr_block] : [""],
    var.allow_vpc_private_cidr_blocks ? var.vpc_private_cidr_blocks : [""],
    [var.extra_allowed_cidr_blocks]
  ))
}

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
  value       = random_password.master.result
  description = "${local.name} master password"
  type        = "SecureString"
  key_id      = var.kms_ssm_key_arn
  tags        = local.tags
}

module "aurora" {
  count                      = var.rds_type == "aurora" ? 1 : 0
  source                     = "terraform-aws-modules/rds-aurora/aws"
  version                    = "= 8.5.0"
  name                       = local.name
  engine                     = "aurora-postgresql"
  engine_version             = var.engine_version
  auto_minor_version_upgrade = false
  instances = {
    1 = {
      instance_class      = var.instance_class
      publicly_accessible = false
    }
  }

  vpc_id                              = var.vpc_id
  db_subnet_group_name                = var.vpc_subnet_group_name
  create_db_subnet_group              = false
  create_security_group               = true
  vpc_security_group_ids              = [aws_security_group.rds_security_group.id]
  iam_database_authentication_enabled = false
  master_username                     = var.master_username
  master_password                     = random_password.master.result
  database_name                       = var.database_name
  storage_encrypted                   = true
  apply_immediately                   = false
  skip_final_snapshot                 = false
  db_parameter_group_name             = aws_db_parameter_group.db.id
  db_cluster_parameter_group_name     = aws_rds_cluster_parameter_group.db[count.index].id
  preferred_maintenance_window        = var.preferred_maintenance_window
  preferred_backup_window             = var.preferred_backup_window
  enabled_cloudwatch_logs_exports     = ["postgresql"]
  copy_tags_to_snapshot               = true

  tags = local.tags
}

module "rds" {
  count = var.rds_type == "rds" ? 1 : 0

  source  = "terraform-aws-modules/rds/aws"
  version = "= 6.2.0"

  identifier                 = local.name
  engine                     = "postgres"
  engine_version             = var.engine_version
  auto_minor_version_upgrade = false
  instance_class             = var.instance_class
  allocated_storage          = var.allocated_storage
  max_allocated_storage      = var.max_allocated_storage

  db_subnet_group_name                = var.vpc_subnet_group_name
  create_db_subnet_group              = false
  vpc_security_group_ids              = [aws_security_group.rds_security_group.id]
  iam_database_authentication_enabled = false
  username                            = var.master_username
  password                            = random_password.master.result
  manage_master_user_password         = false
  db_name                             = var.database_name
  storage_encrypted                   = true
  apply_immediately                   = false
  skip_final_snapshot                 = false
  create_db_parameter_group           = false
  parameter_group_name                = aws_db_parameter_group.db.name
  backup_retention_period             = var.backup_retention_period
  maintenance_window                  = var.preferred_maintenance_window
  backup_window                       = var.preferred_backup_window
  enabled_cloudwatch_logs_exports     = ["postgresql"]
  copy_tags_to_snapshot               = true

  tags = local.tags
}

resource "aws_db_parameter_group" "db" {
  name        = "${local.name}-db-postgres-parameter-group"
  family      = var.family
  description = "${local.name}-db-postgres-parameter-group"

  dynamic "parameter" {
    for_each = var.rds_db_parameters
    content {
      name  = parameter.key
      value = parameter.value
    }
  }

  tags = local.tags
}

resource "aws_rds_cluster_parameter_group" "db" {
  count       = var.rds_type == "aurora" ? 1 : 0
  name        = "${local.name}-postgres-cluster-parameter-group"
  family      = var.family
  description = "${local.name}-postgres-cluster-parameter-group"

  dynamic "parameter" {
    for_each = var.rds_cluster_parameters
    content {
      name  = parameter.key
      value = parameter.value
    }
  }

  tags = local.tags
}

resource "aws_security_group" "rds_security_group" {
  name        = "${local.name}-postgres-security-group"
  description = "Security group for RDS allowing access from private subnets"
  vpc_id      = var.vpc_id

  // Ingress rule to allow traffic from private subnets on the RDS port (e.g., 3306 for MySQL)
  ingress {
    from_port = 5432 # Adjust to the appropriate database port
    to_port   = 5432
    protocol  = "tcp"

    // Allow traffic from each private subnet
    cidr_blocks     = local.allowed_cidr_blocks
    security_groups = [var.bastion_security_group_id]
  }

  // You may need egress rules depending on your use case
  // For example, to allow outgoing traffic to the internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# # Creating databases and users

# resource "random_password" "password" {
#   for_each         = toset(values(var.database_user_map))
#   length           = 20
#   special          = true
#   min_special      = 5
#   override_special = "!#$%^&*()-_=+[]{}<>:?"
#   keepers = {
#     pass_version = 1
#   }
# }

# # Endpoint DNS name does not get immediately resolvable and leads to error, add artificial wait to avoid errors
# resource "null_resource" "wait" {
#   provisioner "local-exec" {
#     interpreter = ["bash", "-c"]
#     command     = "sleep 60"
#   }
#   depends_on = [module.aurora, module.rds]
# }

# resource "postgresql_role" "role" {
#   for_each = toset(values(var.database_user_map))
#   name     = each.key
#   login    = true
#   password = random_password.password[each.key].result

#   # W/A to avoid repeating changes in terraform apply
#   roles       = []
#   search_path = []

#   depends_on = [null_resource.wait]
# }

# resource "postgresql_database" "db" {
#   for_each = var.database_user_map
#   name     = each.key
#   owner    = each.value

#   depends_on = [postgresql_role.role]
# }
