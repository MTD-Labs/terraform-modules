data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  name                = var.name == "" ? "${var.env}-db" : "${var.env}-db-${var.name}"
  enable_rds_alerting = var.rds_type == "rds" && var.enable_rds_alarms
  tags = {
    Name       = local.name
    Env        = var.env
    tf-managed = true
  }
  rds_total_storage_gib = var.allocated_storage

  rds_free_storage_threshold_bytes = floor(
    local.rds_total_storage_gib
    * (100 - var.rds_storage_usage_threshold_percent)
    / 100
    * 1024 * 1024 * 1024
  )
}

locals {
  allowed_cidr_blocks = compact(concat(
    var.allow_vpc_cidr_block ? [var.vpc_cidr_block] : [""],
    var.allow_vpc_private_cidr_blocks ? var.vpc_private_cidr_blocks : [""],
    [var.extra_allowed_cidr_blocks]
  ))
}
resource "random_password" "master" {
  length      = 24
  special     = false # no punctuation at all
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  keepers     = { pass_version = 1 } # bump to rotate
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
      name         = parameter.key
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
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

resource "aws_sns_topic" "rds_alarms" {
  count = local.enable_rds_alerting ? 1 : 0

  name = "${local.name}-rds-alarms"
  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  count = local.enable_rds_alerting ? 1 : 0

  alarm_name          = "${local.name}-rds-cpu-high"
  alarm_description   = "RDS CPU > 80% for 10 minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_cpu_threshold

  dimensions = {
    DBInstanceIdentifier = module.rds[0].db_instance_identifier
  }

  alarm_actions = [aws_sns_topic.rds_alarms[0].arn]
  ok_actions    = [aws_sns_topic.rds_alarms[0].arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_free_memory_low" {
  count = local.enable_rds_alerting ? 1 : 0

  alarm_name          = "${local.name}-rds-free-memory-low"
  alarm_description   = "RDS freeable memory low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = var.rds_free_memory_threshold_bytes

  dimensions = {
    DBInstanceIdentifier = module.rds[0].db_instance_identifier
  }

  alarm_actions = [aws_sns_topic.rds_alarms[0].arn]
  ok_actions    = [aws_sns_topic.rds_alarms[0].arn]
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage_low" {
  count = local.enable_rds_alerting && var.enable_rds_storage_alarm ? 1 : 0

  alarm_name        = "${local.name}-rds-free-storage-low"
  alarm_description = "RDS free storage < (100 - rds_storage_usage_threshold_percent)% – disk usage high"

  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  period              = 300 # 5 minutes
  evaluation_periods  = 2   # 10 minutes total
  comparison_operator = "LessThanThreshold"
  threshold           = local.rds_free_storage_threshold_bytes

  treat_missing_data = "missing"

  dimensions = {
    DBInstanceIdentifier = module.rds[0].db_instance_identifier
  }

  alarm_actions = [aws_sns_topic.rds_alarms[0].arn]
  ok_actions    = [aws_sns_topic.rds_alarms[0].arn]
}

resource "aws_db_event_subscription" "rds_important" {
  count = local.enable_rds_alerting ? 1 : 0

  name      = "${local.name}-rds-important-events"
  sns_topic = aws_sns_topic.rds_alarms[0].arn

  source_type = "db-instance"
  source_ids  = [module.rds[0].db_instance_identifier]

  event_categories = var.rds_event_categories

  enabled = true
  tags    = local.tags
}

data "archive_file" "sns_to_telegram_zip" {
  count       = local.enable_rds_alerting ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/sns-to-telegram.zip"

  source {
    content = <<-EOF
      import json
      import os
      import urllib.request
      import urllib.error
      import html

      TELEGRAM_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN")
      CHAT_ID        = os.environ.get("TELEGRAM_CHAT_ID")

      def send_to_telegram(text: str):
          if not TELEGRAM_TOKEN or not CHAT_ID:
              raise RuntimeError("TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set in environment variables")

          url = f"https://api.telegram.org/bot{TELEGRAM_TOKEN}/sendMessage"

          payload = {
              "chat_id": CHAT_ID,
              "text": text,
              "parse_mode": "HTML",
              "disable_web_page_preview": True,
          }

          data = json.dumps(payload).encode("utf-8")
          req = urllib.request.Request(
              url,
              data=data,
              headers={"Content-Type": "application/json"}
          )

          try:
              with urllib.request.urlopen(req) as resp:
                  body = resp.read().decode("utf-8")
                  print("Telegram response:", body)
          except urllib.error.HTTPError as e:
              err_body = e.read().decode("utf-8")
              print("Telegram HTTPError:", e.code, err_body)
              # Reraise so Lambda shows it as an error in test result
              raise

      def build_alarm_message(subject: str, raw_msg: str) -> str:
          # Try parse CloudWatch alarm JSON
          try:
              data = json.loads(raw_msg)
          except Exception:
              # Fallback: just send subject + raw text
              safe_subject = html.escape(subject or "RDS Alert")
              safe_msg     = html.escape(raw_msg)
              return f"⚠️ <b>{safe_subject}</b>\n\n<pre>{safe_msg}</pre>"

          name   = data.get("AlarmName", "N/A")
          state  = data.get("NewStateValue", "N/A")
          reason = data.get("NewStateReason", "")
          region = data.get("Region", "")
          trigger = data.get("Trigger", {}) or {}

          metric    = trigger.get("MetricName", "")
          threshold = trigger.get("Threshold", "")
          dims      = trigger.get("Dimensions", {})

          db_id = ""

          # Dimensions can be list[ {name, value}, ... ] or a single dict
          if isinstance(dims, list):
              for d in dims:
                  if isinstance(d, dict) and d.get("name") == "DBInstanceIdentifier":
                      db_id = d.get("value", "")
                      break
          elif isinstance(dims, dict):
              if dims.get("name") == "DBInstanceIdentifier":
                  db_id = dims.get("value", "")

          # Choose emoji by state
          state_upper = str(state).upper()
          if state_upper == "ALARM":
              emoji = "❌"
          elif state_upper == "OK":
              emoji = "✅"
          else:
              emoji = "⚠️"

          # Format threshold nicely
          threshold_str = ""
          if threshold != "":
              try:
                  t_val = float(threshold)
                  if metric == "FreeableMemory":
                      # Show both GiB and bytes
                      gib = t_val / (1024 ** 3)
                      threshold_str = f"{gib:.1f} GiB ({int(t_val):,} bytes)"
                  else:
                      threshold_str = f"{t_val:g}"
              except Exception:
                  threshold_str = str(threshold)

          # Shorten long reason: take text before first " ("
          short_reason = reason.split(" (")[0] if reason else ""

          safe_state   = html.escape(state_upper)
          safe_name    = html.escape(name)
          safe_region  = html.escape(region)
          safe_db_id   = html.escape(db_id) if db_id else ""
          safe_metric  = html.escape(str(metric)) if metric else ""
          safe_thresh  = html.escape(threshold_str) if threshold_str else ""
          safe_reason  = html.escape(short_reason)

          lines = []
          # Title line
          lines.append(f"{emoji} <b>{safe_state}</b> RDS alarm")
          # Alarm name
          lines.append(f"<b>{safe_name}</b>")

          if safe_db_id:
              lines.append(f"<b>Instance:</b> {safe_db_id}")

          if safe_region:
              lines.append(f"<b>Region:</b> {safe_region}")

          if safe_metric:
              if safe_thresh:
                  lines.append(f"<b>Metric:</b> {safe_metric} (threshold: {safe_thresh})")
              else:
                  lines.append(f"<b>Metric:</b> {safe_metric}")

          if safe_reason:
              lines.append("")
              lines.append(f"<b>Reason:</b> {safe_reason}")

          # IMPORTANT: real newlines, not "\n" text
          return "\n".join(lines)

      def lambda_handler(event, context):
          print("Incoming event:", json.dumps(event))

          records = event.get("Records", [])
          if not records:
              send_to_telegram("Test message: no Records field in event.")
              return {"statusCode": 200}

          for record in records:
              sns = record.get("Sns", {})
              raw_msg = sns.get("Message", "No SNS Message")
              subject = sns.get("Subject", "RDS Alert")

              text = build_alarm_message(subject, raw_msg)
              send_to_telegram(text)

          return {"statusCode": 200}
      EOF

    filename = "lambda_function.py"
  }
}


resource "aws_lambda_function" "sns_to_telegram" {
  count = local.enable_rds_alerting ? 1 : 0

  function_name = "${local.name}-rds-alarms-to-telegram"
  role          = aws_iam_role.lambda_sns_to_telegram[0].arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"

  filename         = data.archive_file.sns_to_telegram_zip[0].output_path
  source_code_hash = data.archive_file.sns_to_telegram_zip[0].output_base64sha256

  timeout = 10

  environment {
    variables = {
      TELEGRAM_BOT_TOKEN = var.telegram_bot_token
      TELEGRAM_CHAT_ID   = var.telegram_chat_id
    }
  }
}


resource "aws_iam_role" "lambda_sns_to_telegram" {
  count = local.enable_rds_alerting ? 1 : 0

  name = "${local.name}-sns-to-telegram-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  count      = local.enable_rds_alerting ? 1 : 0
  role       = aws_iam_role.lambda_sns_to_telegram[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_sns_topic_subscription" "rds_alarms_lambda" {
  count = local.enable_rds_alerting ? 1 : 0

  topic_arn = aws_sns_topic.rds_alarms[0].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.sns_to_telegram[0].arn
}

resource "aws_lambda_permission" "sns_to_telegram" {
  count = local.enable_rds_alerting ? 1 : 0

  statement_id  = "AllowExecutionFromSNSRDSAlarms"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sns_to_telegram[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.rds_alarms[0].arn
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
