### Prometheus and Grafana on ECS

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  common_tags = {
    Env        = var.env
    tf-managed = true
    tf-module  = "aws/ecs"
  }

  tags = merge({
  }, local.common_tags, var.tags)
}

# Volumes

resource "aws_efs_file_system" "prometheus" {
  tags = {
    Name = "ECS-EFS-Prometheus-FS"
  }
}

resource "aws_efs_file_system" "grafana" {
  tags = {
    Name = "ECS-EFS-Grafana-FS"
  }
}

resource "aws_efs_mount_target" "prometheus" {
  for_each        = toset(var.vpc_subnets)
  file_system_id  = aws_efs_file_system.prometheus.id
  subnet_id       = each.value
  security_groups = [module.efs_security_group.security_group_id]
}

resource "aws_efs_mount_target" "grafana" {
  for_each        = toset(var.vpc_subnets)
  file_system_id  = aws_efs_file_system.grafana.id
  subnet_id       = each.value
  security_groups = [module.efs_security_group.security_group_id]
}

module "efs_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.7.0"

  name   = "efs-mount-target-sg"
  vpc_id = var.vpc_id

  ingress_with_source_security_group_id = [
    {
      from_port                = 2049
      to_port                  = 2049
      protocol                 = "tcp"
      description              = "ECS container to NFS port"
      source_security_group_id = aws_security_group.ecs_monitor.id
    }
  ]

  egress_with_cidr_blocks = [
    {
      rule        = "all-all"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
}

resource "aws_ecs_task_definition" "prometheus" {
  family                   = "prometheus"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.ecs_exec_role_arn
  task_role_arn            = var.ecs_task_role_arn
  cpu                      = 256
  memory                   = 1024

  container_definitions = jsonencode([
    {
      name  = "prometheus"
      image = var.prometheus_image

      command = [
        "--storage.tsdb.retention.time=15d",
        "--config.file=/etc/config/prometheus.yaml",
        "--storage.tsdb.path=/data",
        "--web.console.libraries=/etc/prometheus/console_libraries",
        "--web.console.templates=/etc/prometheus/consoles",
        "--web.enable-lifecycle"
      ],

      portMappings = [
        {
          containerPort = 9090
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "config"
          containerPath = "/etc/config"
          readOnly      = false
        },
        {
          sourceVolume  = "data"
          containerPath = "/data"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.ecs_cloudwatch_group_name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "prometheus"
        }
      }
    },
    {
      name  = "config-reloader"
      image = var.prometheus_config_reloader_image

      environment = [
        { name = "CONFIG_FILE_DIR", value = "/etc/config" },
        { name = "CONFIG_RELOAD_FREQUENCY", value = "60" },
        { name = "PROMETHEUS_CONFIG_PARAMETER_NAME", value = "ECS-Prometheus-Configuration" },
        { name = "DISCOVERY_NAMESPACES_PARAMETER_NAME", value = "ECS-ServiceDiscovery-Namespaces" }
      ]

      mountPoints = [
        {
          sourceVolume  = "config"
          containerPath = "/etc/config"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.ecs_cloudwatch_group_name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "prometheus"
        }
      }
    }
  ])

  volume {
    name = "data"

    efs_volume_configuration {
      file_system_id = aws_efs_file_system.prometheus.id
      root_directory = "/"
    }
  }

  volume {
    name = "config"
  }

  tags = local.tags

}

resource "aws_ecs_task_definition" "grafana" {
  family                   = "grafana"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.ecs_exec_role_arn
  task_role_arn            = var.ecs_task_role_arn
  cpu                      = 256
  memory                   = 512

  container_definitions = jsonencode([
    {
      name  = "grafana"
      image = var.grafana_image

      portMappings = [
        {
          containerPort = 3000
        }
      ]

      mountPoints = [
        {
          sourceVolume  = "data"
          containerPath = "/var/lib/grafana"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = var.ecs_cloudwatch_group_name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "grafana"
        }
      }
    }
  ])

  volume {
    name = "data"

    efs_volume_configuration {
      file_system_id = aws_efs_file_system.grafana.id
      root_directory = "/"
    }
  }

  tags = local.tags

}

locals {
  ecs_task_arns = {
    "prometheus" = aws_ecs_task_definition.prometheus.arn
    "grafana"    = aws_ecs_task_definition.grafana.arn
  }
}

resource "aws_service_discovery_service" "service_discovery_service" {
  for_each = toset(["prometheus", "grafana"])

  name = each.value

  dns_config {
    namespace_id = var.ecs_service_discovery_namespace_id

    dns_records {
      ttl  = 15
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_service" "prometheus" {
  for_each = toset(["prometheus", "grafana"])

  name                               = each.value
  cluster                            = var.ecs_cluster_id
  task_definition                    = local.ecs_task_arns[each.value]
  desired_count                      = 1
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  launch_type                        = "FARGATE"

  network_configuration {
    subnets         = var.vpc_subnets
    security_groups = [aws_security_group.ecs_monitor.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.service_discovery_service[each.value].arn
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

}

resource "aws_security_group" "ecs_monitor" {
  name        = "monitor"
  description = "Allow incoming traffic for Prometheus & Grafana ECS containers"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.vpc_private_cidr_blocks
  }

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [var.alb_security_group]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name = "Prometheus"
  }, local.common_tags)
}
