data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}

locals {
  name                  = var.name == "" ? "${var.env}-docdb" : "${var.env}-docdb-${var.name}"
  enable_docdb_alerting = var.enable_docdb_alarms
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
  length      = 24
  special     = false # no punctuation at all
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  keepers     = { pass_version = 1 } # bump to rotate
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

resource "aws_sns_topic" "docdb_alarms" {
  count = local.enable_docdb_alerting ? 1 : 0

  name = "${local.name}-docdb-alarms"
  tags = local.tags
}

data "archive_file" "docdb_sns_to_telegram_zip" {
  count       = local.enable_docdb_alerting ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/docdb-sns-to-telegram.zip"

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
              raise

      def build_alarm_message(subject: str, raw_msg: str) -> str:
          # Try parse CloudWatch alarm JSON
          try:
              data = json.loads(raw_msg)
          except Exception:
              safe_subject = html.escape(subject or "Alarm")
              safe_msg     = html.escape(raw_msg)
              return f"⚠️ <b>{safe_subject}</b>\\n\\n<pre>{safe_msg}</pre>"

          name    = data.get("AlarmName", "N/A")
          state   = data.get("NewStateValue", "N/A")
          reason  = data.get("NewStateReason", "")
          region  = data.get("Region", "")
          trigger = data.get("Trigger", {}) or {}

          metric    = trigger.get("MetricName", "")
          threshold = trigger.get("Threshold", "")
          dims      = trigger.get("Dimensions", {})

          resource_id = ""

          # Dimensions can be list[ {name, value}, ... ] or a single dict
          if isinstance(dims, list):
              for d in dims:
                  if not isinstance(d, dict):
                      continue
                  dim_name  = d.get("name")
                  dim_value = d.get("value", "")
                  if dim_name in ("DBInstanceIdentifier", "DBClusterIdentifier", "Broker", "BrokerId"):
                      resource_id = dim_value
                      break
          elif isinstance(dims, dict):
              dim_name  = dims.get("name")
              dim_value = dims.get("value", "")
              if dim_name in ("DBInstanceIdentifier", "DBClusterIdentifier", "Broker", "BrokerId"):
                  resource_id = dim_value

          # Emoji by state
          state_upper = str(state).upper()
          if state_upper == "ALARM":
              emoji = "❌"
          elif state_upper == "OK":
              emoji = "✅"
          else:
              emoji = "⚠️"

          # Threshold formatting
          threshold_str = ""
          if threshold != "":
              try:
                  t_val = float(threshold)
                  threshold_str = f"{t_val:g}"
              except Exception:
                  threshold_str = str(threshold)

          # Shorten reason
          short_reason = reason.split(" (")[0] if reason else ""

          safe_state    = html.escape(state_upper)
          safe_name     = html.escape(name)
          safe_region   = html.escape(region)
          safe_resource = html.escape(resource_id) if resource_id else ""
          safe_metric   = html.escape(str(metric)) if metric else ""
          safe_thresh   = html.escape(threshold_str) if threshold_str else ""
          safe_reason   = html.escape(short_reason)

          lines = []
          lines.append(f"{emoji} <b>{safe_state}</b> CloudWatch alarm")
          lines.append(f"<b>{safe_name}</b>")

          if safe_resource:
              lines.append(f"<b>Resource:</b> {safe_resource}")

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

          # IMPORTANT: real newlines here
          return "\\n".join(lines).replace("\\\\n", "\\n")

      def lambda_handler(event, context):
          print("Incoming event:", json.dumps(event))

          records = event.get("Records", [])
          if not records:
              send_to_telegram("Test message: no Records field in event.")
              return {"statusCode": 200}

          for record in records:
              sns = record.get("Sns", {})
              raw_msg = sns.get("Message", "No SNS Message")
              subject = sns.get("Subject", "Alarm")

              text = build_alarm_message(subject, raw_msg)
              send_to_telegram(text)

          return {"statusCode": 200}
      EOF

    filename = "lambda_function.py"
  }
}

resource "aws_iam_role" "docdb_lambda_sns_to_telegram" {
  count = local.enable_docdb_alerting ? 1 : 0

  name = "${local.name}-docdb-sns-to-telegram-role"

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

resource "aws_iam_role_policy_attachment" "docdb_lambda_basic" {
  count      = local.enable_docdb_alerting ? 1 : 0
  role       = aws_iam_role.docdb_lambda_sns_to_telegram[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "docdb_sns_to_telegram" {
  count = local.enable_docdb_alerting ? 1 : 0

  function_name = "${local.name}-docdb-alarms-to-telegram"
  role          = aws_iam_role.docdb_lambda_sns_to_telegram[0].arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"

  filename         = data.archive_file.docdb_sns_to_telegram_zip[0].output_path
  source_code_hash = data.archive_file.docdb_sns_to_telegram_zip[0].output_base64sha256

  timeout = 10

  environment {
    variables = {
      TELEGRAM_BOT_TOKEN = var.telegram_bot_token
      TELEGRAM_CHAT_ID   = var.telegram_chat_id
    }
  }
}

resource "aws_sns_topic_subscription" "docdb_alarms_lambda" {
  count = local.enable_docdb_alerting ? 1 : 0

  topic_arn = aws_sns_topic.docdb_alarms[0].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.docdb_sns_to_telegram[0].arn
}

resource "aws_lambda_permission" "docdb_sns_to_telegram" {
  count = local.enable_docdb_alerting ? 1 : 0

  statement_id  = "AllowExecutionFromSNSDocDBAlarms"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.docdb_sns_to_telegram[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.docdb_alarms[0].arn
}

resource "aws_cloudwatch_metric_alarm" "docdb_cpu_high" {
  count = local.enable_docdb_alerting ? 1 : 0

  alarm_name        = "${local.name}-docdb-cpu-high"
  alarm_description = "Amazon DocumentDB CPU > ${var.docdb_cpu_threshold}% for 10 minutes"

  namespace           = "AWS/DocDB"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.docdb_cpu_threshold

  treat_missing_data = "missing"

  dimensions = {
    DBInstanceIdentifier = local.name
  }

  alarm_actions = [aws_sns_topic.docdb_alarms[0].arn]
  ok_actions    = [aws_sns_topic.docdb_alarms[0].arn]
}

resource "aws_cloudwatch_metric_alarm" "docdb_free_memory_low" {
  count = local.enable_docdb_alerting ? 1 : 0

  alarm_name        = "${local.name}-docdb-free-memory-low"
  alarm_description = "Amazon DocumentDB FreeableMemory below configured threshold"

  namespace           = "AWS/DocDB"
  metric_name         = "FreeableMemory"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "LessThanThreshold"
  threshold           = var.docdb_free_memory_threshold_bytes

  treat_missing_data = "missing"

  dimensions = {
    DBInstanceIdentifier = local.name
  }

  alarm_actions = [aws_sns_topic.docdb_alarms[0].arn]
  ok_actions    = [aws_sns_topic.docdb_alarms[0].arn]
}

resource "aws_cloudwatch_metric_alarm" "docdb_connections_zero" {
  count = local.enable_docdb_alerting ? 1 : 0

  alarm_name        = "${local.name}-docdb-connections-zero"
  alarm_description = "Amazon DocumentDB DatabaseConnections == 0 for a prolonged period (approximate uptime check)"

  namespace           = "AWS/DocDB"
  metric_name         = "DatabaseConnections"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = var.docdb_connection_zero_alarm_periods
  comparison_operator = "LessThanThreshold"
  threshold           = 1

  treat_missing_data = "missing"

  dimensions = {
    DBInstanceIdentifier = local.name
  }

  alarm_actions = [aws_sns_topic.docdb_alarms[0].arn]
  ok_actions    = [aws_sns_topic.docdb_alarms[0].arn]
}
