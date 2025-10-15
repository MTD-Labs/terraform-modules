data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  common_tags = {
    Env        = var.env
    tf-managed = true
    tf-module  = "aws/ecs"
  }

  tags = merge({
    Name = var.cluster_name
  }, local.common_tags, var.tags)
}

### ECS CLUSTER

resource "aws_ecs_cluster" "cluster" {
  name = var.cluster_name
  tags = local.tags
}

### ECS TASKS

resource "aws_cloudwatch_log_group" "log_group" {
  name              = var.cluster_name
  retention_in_days = 30

  tags = local.tags
}

resource "aws_ecs_task_definition" "container_task_definitions" {
  for_each                 = { for idx, container in var.containers : idx => container }
  family                   = each.value["name"]
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.exec_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  cpu                      = each.value["cpu"]
  memory                   = each.value["memory"]

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  dynamic "volume" {
    for_each = var.efs_enabled ? each.value.volumes : []
    content {
      name = volume.value.name

      dynamic "efs_volume_configuration" {
        for_each = try(aws_efs_file_system.ecs[0].id, null) != null ? [volume.value] : []
        content {
          file_system_id          = aws_efs_file_system.ecs[0].id
          root_directory          = "/${each.value.name}"
          transit_encryption      = "ENABLED"
          transit_encryption_port = 2999

          authorization_config {
            access_point_id = aws_efs_access_point.ecs[each.key].id
            iam             = "ENABLED"
          }
        }
      }
    }
  }

  container_definitions = jsonencode(concat(
    [for container in [each.value] : {
      name    = container["name"]
      image   = container["image"]
      command = container["command"]
      cpu     = container["cpu"]
      memory  = container["memory"]
      portMappings = [
        {
          containerPort = container["port"]
        }
      ]

      environment = [for key, value in container["envs"] :
        {
          name  = key
          value = value
        }
      ]

      secrets = [for key, value in container["secrets"] :
        {
          name      = key
          valueFrom = value
        }
      ]

      mountPoints = var.efs_enabled ? [
        for v in each.value.volumes : {
          containerPath = v.container_path
          sourceVolume  = v.name
          readOnly      = coalesce(v.read_only, false)
        }
      ] : []

      logConfiguration = var.loki_enabled ? {
        logDriver = "awsfirelens"
        options = {
          "Name"              = "loki"
          "Host"              = aws_instance.loki_grafana[0].private_ip
          "Port"              = "3100"
          "Labels"            = "{job=\"${container["name"]}\""
          "LabelKeys"         = "container_name,ecs_task_definition,source,ecs_cluster"
          "DropSingleKey"     = "true"
          "RemoveKeys"        = "container_id,ecs_task_arn"
          "AutoRetryRequests" = "true"
          "LineFormat"        = "key_value"
        }
        } : {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.log_group.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = container["name"]
        }
      }
    }],
    var.loki_enabled ? [{
      name      = "log_router"
      image     = var.fluentbit_image
      essential = true
      firelensConfiguration = {
        type = "fluentbit"
        options = {
          "enable-ecs-log-metadata" = "true"
        }
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.log_group.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "firelens"
        }
      }
      memoryReservation = var.fluentbit_memoryreservation
    }] : []
  ))
}

resource "aws_service_discovery_private_dns_namespace" "service_discovery_namespace" {
  name        = var.cluster_name
  description = "${title(var.cluster_name)} Service Discovery Namespace"
  vpc         = var.vpc_id
}

resource "aws_service_discovery_service" "service_discovery_service" {
  for_each = { for idx, container in var.containers : idx => container }

  name = each.value["name"]

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.service_discovery_namespace.id

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

resource "aws_ecs_service" "container_service" {
  for_each                           = { for idx, container in var.containers : idx => container }
  name                               = each.value["name"]
  cluster                            = aws_ecs_cluster.cluster.id
  task_definition                    = aws_ecs_task_definition.container_task_definitions[each.key].arn
  desired_count                      = each.value["min_count"]
  deployment_minimum_healthy_percent = floor(100 / each.value["min_count"])
  deployment_maximum_percent         = each.value["min_count"] == 1 ? 200 : 150
  launch_type                        = "FARGATE"
  enable_execute_command             = true
  force_new_deployment               = true
  dynamic "load_balancer" {
    for_each = length(each.value.path) == 0 ? [] : [for path in each.value.path : path]

    content {
      target_group_arn = aws_alb_target_group.service_target_group[each.key].arn
      container_name   = each.value["name"]
      container_port   = each.value["port"]
    }
  }

  network_configuration {
    subnets         = var.vpc_subnets
    security_groups = [aws_security_group.ecs[each.key].id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.service_discovery_service[each.key].arn
  }

  lifecycle {
    ignore_changes = [desired_count]
  }

}

resource "aws_security_group" "ecs" {
  for_each    = { for idx, container in var.containers : idx => container }
  name        = each.value["name"]
  description = "Allow incoming traffic for ECS containers"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = each.value["port"]
    to_port         = each.value["port"]
    protocol        = "tcp"
    security_groups = [var.alb_security_group]
  }

  ingress {
    from_port   = each.value["port"]
    to_port     = each.value["port"]
    protocol    = "tcp"
    cidr_blocks = var.vpc_private_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name = each.value["name"]
  }, local.common_tags)
}

resource "aws_appautoscaling_target" "ecs_target" {
  for_each           = { for idx, container in var.containers : idx => container }
  max_capacity       = each.value["max_count"]
  min_capacity       = each.value["min_count"]
  resource_id        = format("%s/%s/%s", "service", aws_ecs_cluster.cluster.name, aws_ecs_service.container_service[each.key].name)
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  for_each           = { for idx, container in var.containers : idx => container }
  name               = format("%s-%s", each.value["name"], "cpu-policy")
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = each.value["target_cpu_threshold"]

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  for_each           = { for idx, container in var.containers : idx => container }
  name               = format("%s-%s", each.value["name"], "memory-policy")
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = each.value["target_mem_threshold"]

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
  }
}

### IAM

resource "aws_iam_role" "exec_role" {
  name = "${var.cluster_name}-exec-role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ecs-tasks.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
  tags = {
    Name = "${var.cluster_name}-exec-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_exec_policy" {
  role       = aws_iam_role.exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_exec_ssm_policy" {
  role       = aws_iam_role.exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecs_exec_ssm_policy_attachment" {
  role       = aws_iam_role.exec_role.name
  policy_arn = aws_iam_policy.ecs_exec_ssm_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_exec_task_policy" {
  role       = aws_iam_role.exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_exec_ssm_policy_attachment_task" {
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.ecs_exec_ssm_policy.arn
}

resource "aws_iam_role_policy_attachment" "ecs_task_ssm_core" {
  role       = aws_iam_role.task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


resource "aws_iam_role" "task_role" {
  name = "${var.cluster_name}-task-role"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ecs-tasks.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
  tags = {
    Name = "${var.cluster_name}-task-role"
  }
}

resource "aws_iam_policy" "ecs_exec_ssm_policy" {
  name        = "${var.cluster_name}-ecs-exec-ssm-policy"
  description = "Allows ECS Exec to use SSM Session Manager"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecs_task_policy" {
  role       = aws_iam_role.task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Ability to obtain SSM parameters

resource "aws_iam_policy" "ssm_get_policy" {
  name        = "${var.cluster_name}-ssm-get-policy"
  description = "Allows to get SSM parameters, including encrypted ones"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter*",
        "secretsmanager:GetSecret*",
        "kms:Decrypt"
      ],
      "Resource": [
        "arn:aws:ssm:${var.region}:${local.account_id}:parameter/*",
        "arn:aws:kms:${var.region}:${local.account_id}:key/*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "ecr_pull_assume_role" {
  role       = aws_iam_role.exec_role.name
  policy_arn = aws_iam_policy.ssm_get_policy.arn
}


resource "aws_vpc_endpoint" "ssm_messages" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids = [
    var.alb_security_group
  ]
  subnet_ids = var.vpc_subnets
}

resource "aws_iam_user" "exec_user" {
  name = "${var.env}-${var.name}_exec_user"

  tags = {
    Env        = var.env
    Project    = var.name
    tf-managed = true
  }
}

resource "aws_iam_user_policy" "exec_user_policy" {
  name = "${var.env}-${var.name}_ecs_exec_policy"
  user = aws_iam_user.exec_user.name

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ecs:ExecuteCommand",
                "ecs:ListTasks",
                "ecs:DescribeTasks",
                "ecs:DescribeServices",
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}