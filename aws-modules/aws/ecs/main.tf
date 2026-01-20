data "aws_caller_identity" "current" {}

# Data source to check if Loki instance exists
data "aws_instances" "loki" {
  filter {
    name   = "tag:Name"
    values = ["${var.cluster_name}-loki-grafana"]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

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

  # Use the data source to get Loki IP
  loki_host                        = var.loki_enabled && length(data.aws_instances.loki.private_ips) > 0 ? data.aws_instances.loki.private_ips[0] : ""
  ecs_scale_alarm_ok_notifications = var.ecs_scale_alarm_ok_notifications
}

### ECS CLUSTER

resource "aws_ecs_cluster" "cluster" {
  name = var.cluster_name
  tags = local.tags

  dynamic "setting" {
    for_each = var.cloudwatch_insights_enabled ? [1] : []
    content {
      name  = "containerInsights"
      value = "enabled"
    }
  }

}

### PER-TASK CLOUDWATCH LOG GROUPS (env-container_name, 14 days)

resource "aws_cloudwatch_log_group" "container" {
  for_each          = { for idx, c in var.containers : idx => c }
  name              = each.value.name
  retention_in_days = var.cloudwatch_log_retention_days
  tags              = local.tags
}

### ECS TASKS
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

      # Health check configuration - CORRECTED
      healthCheck = try(container["container_health_check"], null) != null ? {
        command = [
          "CMD-SHELL",
          try(container["container_health_check"]["command"], "curl -f http://localhost:${container["port"]}${try(container["health_check"]["path"], "/")} || exit 1")
        ]
        interval    = try(container["container_health_check"]["interval"], 30)
        retries     = try(container["container_health_check"]["retries"], 3)
        timeout     = try(container["container_health_check"]["timeout"], 5)
        startPeriod = try(container["container_health_check"]["start_period"], 60)
      } : null

      # If Loki is enabled and host is known, send app logs to FireLens (Loki).
      # Otherwise, use per-task CloudWatch log group (env-container_name).
      logConfiguration = var.loki_enabled && local.loki_host != "" ? {
        logDriver = "awsfirelens"
        options = {
          "Name"       = "loki"
          "Host"       = local.loki_host
          "Port"       = "3100"
          "Labels"     = "{job=\\\"${container["name"]}\\\"}"
          "LabelKeys"  = "container_name,ecs_task_definition,source,ecs_cluster"
          "RemoveKeys" = "container_id,ecs_task_arn"
          "LineFormat" = "key_value"
        }
        } : {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.container[each.key].name
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
      # FireLens sidecar logs go to the same per-task log group
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.container[each.key].name
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
    cidr_blocks = [var.vpc_cidr_block]
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
  name               = "${each.value.name}-cpu-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = each.value.target_cpu_threshold
    scale_out_cooldown = each.value.cpu_scale_out_cooldown
    scale_in_cooldown  = each.value.cpu_scale_in_cooldown

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}

resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  for_each           = { for idx, container in var.containers : idx => container }
  name               = "${each.value.name}-memory-policy"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    target_value       = each.value.target_mem_threshold
    scale_out_cooldown = each.value.mem_scale_out_cooldown
    scale_in_cooldown  = each.value.mem_scale_in_cooldown

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

data "archive_file" "logs_to_slack_zip" {
  count       = var.subscription_filter_enabled ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/logs-to-slack.zip"

  source {
    filename = "lambda_function.py"
    content  = <<-EOF
      import os
      import json
      import base64
      import gzip
      import re
      import urllib.request

      SLACK_WEBHOOK_URL = os.environ["SLACK_WEBHOOK_URL"]
      ENV               = os.environ.get("ENV", "prod")

      # Strip ANSI color codes like \x1b[33m ... \x1b[39m
      ANSI_RE = re.compile(r"\\x1b\\[[0-9;]*m")

      def send_to_slack(text: str):
          data = json.dumps({"text": text}).encode("utf-8")
          req = urllib.request.Request(
              SLACK_WEBHOOK_URL,
              data=data,
              headers={"Content-Type": "application/json"},
              method="POST",
          )
          with urllib.request.urlopen(req) as resp:
              resp.read()

      def lambda_handler(event, context):
          compressed = base64.b64decode(event["awslogs"]["data"])
          payload = json.loads(gzip.decompress(compressed))

          log_group = payload.get("logGroup", "unknown")

          for le in payload.get("logEvents", []):
              message = (le.get("message") or "").strip()
              if not message:
                  continue

              lower = message.lower()

              # EXCLUDE DEBUG logs (any case)
              if "[debug]" in lower:
                  continue
              EXCLUDES = [
                  "indexeddb is not defined",
                  "0 errors",
                  "profile.poolshistory.pools.title",
                  "incorrect locale information provided",
                  "ferrorlayouts",
                  "loaded 60 error",
                  "might be from an older or newer deployment",
              ]
              if any(x in lower for x in EXCLUDES):
                continue
              if "indexedDB is not defined" in lower:
                  continue
              if "0 errors" in lower:
                  continue
              if "profile.poolsHistory.pools.title" in lower:
                  continue
              if "Incorrect locale information provided" in lower:
                  continue
              if "ferrorlayouts" in lower:
                  continue
              # EXCLUDE: "error" when it appears inside paths, filenames, or known noisy module names
              if "error" in lower:
                  if (
                      # paths / static files
                      ("/" in lower and (
                          ".js" in lower
                          or ".map" in lower
                          or ".json" in lower
                          or "/error" in lower
                      ))
                      # NestJS noisy module
                      or "errormessagesmodule" in lower
                  ):
                      continue
              # Skip lines that are not error or warn at all
              if "error" not in lower and "warn" not in lower:
                  continue

              # Skip known noisy startup logs
              if "/error" in message:
                  continue
              if "loaded 60 error" in lower:
                  continue

              # Strip ANSI color codes
              clean_message = ANSI_RE.sub("", message)

              # Strip "297484203613:" prefix if present
              ecs_service = log_group.split(":", 1)[-1]

              text = (
                  "*Trendex Production Error Alert — FIRING*\n\n"
                  f"*Ecs-Container:* `prod-trendex`\n"
                  f"*ECS-Service:* `{ecs_service}`\n"
                  f"*Environment:* `{ENV}`\n"
                  f"*Message:*\n```{clean_message[:3900]}```"
              )

              send_to_slack(text)

          return {"statusCode": 200}

      EOF
  }
}

resource "aws_iam_role" "logs_to_slack_role" {
  count = var.subscription_filter_enabled ? 1 : 0
  name  = "${var.cluster_name}-logs-to-slack-role"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  EOF
}

resource "aws_iam_policy" "logs_to_slack_policy" {
  count       = var.subscription_filter_enabled ? 1 : 0
  name        = "${var.cluster_name}-logs-to-slack-policy"
  description = "Allow Lambda to write logs to CloudWatch"

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:${var.region}:${local.account_id}:log-group:/aws/lambda/${var.cluster_name}-logs-to-slack:*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "logs_to_slack_attach" {
  count      = var.subscription_filter_enabled ? 1 : 0
  role       = aws_iam_role.logs_to_slack_role[0].name
  policy_arn = aws_iam_policy.logs_to_slack_policy[0].arn
}

resource "aws_lambda_function" "logs_to_slack" {
  count = var.subscription_filter_enabled ? 1 : 0

  function_name    = "${var.cluster_name}-logs-to-slack"
  filename         = data.archive_file.logs_to_slack_zip[0].output_path
  source_code_hash = data.archive_file.logs_to_slack_zip[0].output_base64sha256

  role    = aws_iam_role.logs_to_slack_role[0].arn
  handler = "lambda_function.lambda_handler"
  runtime = "python3.12"
  timeout = 10

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.subscription_filter_slack_webhook_url
      ENV               = var.env
    }
  }

  tags = local.common_tags
}

resource "aws_lambda_permission" "allow_cw_logs" {
  count = var.subscription_filter_enabled ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatchLogs"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.logs_to_slack[0].function_name
  principal     = "logs.${var.region}.amazonaws.com"
  # Optionally restrict SourceArn if you want
}

resource "aws_cloudwatch_log_subscription_filter" "ecs_errors_to_slack" {
  for_each = var.subscription_filter_enabled ? aws_cloudwatch_log_group.container : {}

  name            = "${each.value.name}-errors-to-slack"
  log_group_name  = each.value.name
  filter_pattern  = var.subscription_filter_pattern
  destination_arn = aws_lambda_function.logs_to_slack[0].arn

  depends_on = [aws_lambda_permission.allow_cw_logs]
}

resource "aws_sns_topic" "ecs_scale_alarms" {
  count = var.ecs_scale_alarm_enabled ? 1 : 0

  name = "${var.env}-${var.name}-ecs-scale-alarms"
  tags = local.common_tags
}

data "archive_file" "ecs_scale_to_slack_zip" {
  count       = var.ecs_scale_alarm_enabled ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/ecs-scale-to-slack.zip"

  source {
    filename = "lambda_function.py"
    content  = <<-EOF
      import json
      import urllib.request
      import re
      import os

      SLACK_WEBHOOK_URL = os.environ["SLACK_WEBHOOK_URL"]

      def extract_current_value(reason: str) -> str:
          """
          Try to extract the current metric value from NewStateReason.
          Example: "Threshold Crossed: 1 out of the last 1 datapoints [2.0 (17/11/25 11:58:00)] ..."
          We'll grab the 2.0
          """
          if not reason:
              return "unknown"

          m = re.search(r"\\[([\\d\\.]+) \\(", reason)
          if m:
              return m.group(1)
          return "unknown"

      def lambda_handler(event, context):
          print("Raw event:", json.dumps(event))

          record = event["Records"][0]
          sns_message = record["Sns"]["Message"]

          try:
              data = json.loads(sns_message)
          except json.JSONDecodeError:
              payload = {
                  "text": f"🚨 ECS Containers Count Alert (raw message):\\n```{sns_message}```"
              }
          else:
              alarm_name = data.get("AlarmName", "unknown")
              region = data.get("Region", "unknown")
              new_state = data.get("NewStateValue", "unknown")
              reason = data.get("NewStateReason", "")

              trigger = data.get("Trigger", {})
              metric_name = trigger.get("MetricName", "unknown")

              dims = {
                  d.get("name"): d.get("value")
                  for d in trigger.get("Dimensions", [])
              }
              service_name = dims.get("ServiceName", "unknown")
              cluster_name = dims.get("ClusterName", "unknown")

              current_value = extract_current_value(reason)

              text = (
                  "🚨 *ECS Scaling Alert*\\n"
                  f"*Alarm:* `{alarm_name}`\\n"
                  f"*Region:* `{region}`\\n"
                  f"*Cluster:* `{cluster_name}`\\n"
                  f"*Service:* `{service_name}`\\n"
                  f"*Metric:* `{metric_name}`\\n"
                  f"*Current value:* *{current_value}*\\n"
                  f"*State:* `{new_state}`\\n"
                  f"*Reason:* {reason}"
              )

              payload = {"text": text}

          req = urllib.request.Request(
              SLACK_WEBHOOK_URL,
              data=json.dumps(payload).encode("utf-8"),
              headers={"Content-Type": "application/json"}
          )

          urllib.request.urlopen(req)

          return {"status": "OK"}
      EOF
  }
}

resource "aws_iam_role" "ecs_scale_to_slack_role" {
  count = var.ecs_scale_alarm_enabled ? 1 : 0
  name  = "${var.cluster_name}-ecs-scale-to-slack-role"

  assume_role_policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  EOF
}

resource "aws_iam_policy" "ecs_scale_to_slack_policy" {
  count       = var.ecs_scale_alarm_enabled ? 1 : 0
  name        = "${var.cluster_name}-ecs-scale-to-slack-policy"
  description = "Allow Lambda to write logs to CloudWatch"

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:${var.region}:${local.account_id}:log-group:/aws/lambda/${var.cluster_name}-ecs-scale-to-slack:*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role_policy_attachment" "ecs_scale_to_slack_attach" {
  count      = var.ecs_scale_alarm_enabled ? 1 : 0
  role       = aws_iam_role.ecs_scale_to_slack_role[0].name
  policy_arn = aws_iam_policy.ecs_scale_to_slack_policy[0].arn
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_full_access" {
  role       = aws_iam_role.task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_policy" "ecs_task_s3_policy" {
  name = "${var.cluster_name}-ecs-task-s3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::*",
          "arn:aws:s3:::*/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_attach" {
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.ecs_task_s3_policy.arn
}


resource "aws_lambda_function" "ecs_scale_to_slack" {
  count = var.ecs_scale_alarm_enabled ? 1 : 0

  function_name    = "${var.cluster_name}-ecs-scale-to-slack"
  filename         = data.archive_file.ecs_scale_to_slack_zip[0].output_path
  source_code_hash = data.archive_file.ecs_scale_to_slack_zip[0].output_base64sha256

  role    = aws_iam_role.ecs_scale_to_slack_role[0].arn
  handler = "lambda_function.lambda_handler"
  runtime = "python3.12"
  timeout = 10

  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.ecs_scale_alarm_slack_webhook_url
      ENV               = var.env
    }
  }

  tags = local.common_tags
}

resource "aws_lambda_permission" "ecs_scale_allow_sns" {
  count = var.ecs_scale_alarm_enabled ? 1 : 0

  statement_id  = "AllowExecutionFromSNSForEcsScale"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ecs_scale_to_slack[0].arn
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.ecs_scale_alarms[0].arn
}

resource "aws_sns_topic_subscription" "ecs_scale_lambda_subscription" {
  count = var.ecs_scale_alarm_enabled ? 1 : 0

  topic_arn = aws_sns_topic.ecs_scale_alarms[0].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.ecs_scale_to_slack[0].arn

  depends_on = [aws_lambda_permission.ecs_scale_allow_sns]
}

resource "aws_cloudwatch_metric_alarm" "ecs_task_count" {
  for_each = var.ecs_scale_alarm_enabled ? { for idx, c in var.containers : idx => c } : {}

  alarm_name          = "${each.value.name}-ecs-count"
  alarm_description   = "ECS service ${each.value.name} in ${var.env} scaled above its baseline task count."
  namespace           = "ECS/ContainerInsights"
  metric_name         = "RunningTaskCount"
  statistic           = "Average"
  period              = 120 # 1 minute
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  comparison_operator = "GreaterThanThreshold"
  threshold           = each.value["min_count"] # baseline count
  treat_missing_data  = "missing"

  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = each.value.name
  }

  alarm_actions = [aws_sns_topic.ecs_scale_alarms[0].arn]

  ok_actions = var.ecs_scale_alarm_ok_notifications ? [aws_sns_topic.ecs_scale_alarms[0].arn] : []
}
