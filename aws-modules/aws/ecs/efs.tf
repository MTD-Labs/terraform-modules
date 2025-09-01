resource "aws_efs_file_system" "ecs" {
  count          = var.efs_enabled ? 1 : 0
  creation_token = "${var.cluster_name}-efs"

  performance_mode                = var.efs_performance_mode
  throughput_mode                 = var.efs_throughput_mode
  provisioned_throughput_in_mibps = var.efs_provisioned_throughput

  lifecycle {
    prevent_destroy = true
  }

  tags = merge({
    Name = "${var.cluster_name}-efs"
  }, local.common_tags)
}

resource "aws_efs_mount_target" "ecs" {
  count           = var.efs_enabled ? length(var.vpc_subnets) : 0
  file_system_id  = aws_efs_file_system.ecs[0].id
  subnet_id       = var.vpc_subnets[count.index]
  security_groups = [aws_security_group.efs[0].id]
}

resource "aws_security_group" "efs" {
  count       = var.efs_enabled ? 1 : 0
  name        = "${var.cluster_name}-efs-sg"
  description = "Allow EFS access from ECS containers"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [for sg in aws_security_group.ecs : sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name = "${var.cluster_name}-efs-sg"
  }, local.common_tags)
}

resource "aws_efs_access_point" "ecs" {
  for_each = { for idx, container in var.containers : idx => container if var.efs_enabled && length(container.volumes) > 0 }

  file_system_id = aws_efs_file_system.ecs[0].id

  root_directory {
    path = "/${each.value.name}"
    creation_info {
      owner_uid   = 1000
      owner_gid   = 1000
      permissions = "755"
    }
  }

  posix_user {
    uid = 1000
    gid = 1000
  }

  tags = merge({
    Name = "${var.cluster_name}-${each.value.name}-ap"
  }, local.common_tags)
}