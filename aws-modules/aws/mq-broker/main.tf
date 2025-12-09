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

  allowed_cidr_blocks = compact(concat(
    var.allow_vpc_private_cidr_blocks ? var.vpc_private_cidr_blocks : [],
    var.extra_allowed_cidr_blocks != "" ? [var.extra_allowed_cidr_blocks] : []
  ))

  enable_mq_alerting = var.enable_mq_alarms

  # free threshold in bytes, like you do for RDS
  # Example: total = 100 GiB, usage_threshold = 80%  → free threshold = 20 GiB
  mq_disk_free_threshold_bytes = floor(
    var.mq_disk_total_gib
    * (100 - var.mq_disk_usage_threshold_percent)
    / 100
    * 1024 * 1024 * 1024
  )
}


# Admin password (safe: A–Z, a–z, 0–9 only)
resource "random_password" "admin_password" {
  length      = 24
  special     = false # no punctuation at all
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  keepers     = { pass_version = 1 } # bump to rotate
}

resource "random_password" "user_password" {
  for_each    = var.users
  length      = 24
  special     = false
  min_upper   = 2
  min_lower   = 2
  min_numeric = 2
  keepers     = { pass_version = 1 } # bump to rotate
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
  for_each    = var.users
  name        = "${local.name}-${each.key}-password"
  value       = random_password.user_password[each.key].result
  description = "${local.name} ${each.key} user password"
  type        = "SecureString"
  key_id      = var.kms_ssm_key_arn
  tags        = local.tags
}

# --- Security Group (RabbitMQ ports only) ---
resource "aws_security_group" "mq_security_group" {
  name        = "${local.name}-amazon-mq-sg"
  description = "Security group for Amazon MQ (RabbitMQ)"
  vpc_id      = var.vpc_id
  tags        = local.tags

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = local.allowed_cidr_blocks
    security_groups = var.bastion_security_group_id != "" ? [var.bastion_security_group_id] : []
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Amazon MQ Broker (RabbitMQ) ---
resource "aws_mq_broker" "amazon_mq" {
  broker_name                = local.name
  engine_type                = var.engine_type    # must be "RabbitMQ"
  engine_version             = var.engine_version # e.g., "3.13.2" if supported in your region
  host_instance_type         = var.instance_type
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  deployment_mode            = var.deployment_mode # e.g., "SINGLE_INSTANCE" or "CLUSTER_MULTI_AZ"
  publicly_accessible        = false
  security_groups            = [aws_security_group.mq_security_group.id]

  # Provide one or more subnets as required by your deployment mode
  subnet_ids = var.vpc_subnets

  # RabbitMQ supports SIMPLE only
  authentication_strategy = var.authentication_strategy

  # Encryption
  encryption_options {
    kms_key_id        = var.kms_mq_key_arn
    use_aws_owned_key = var.kms_mq_key_arn == null || var.kms_mq_key_arn == "" ? true : false
  }

  # Logging (RabbitMQ: only 'general' is supported)
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

  # dynamic "user" {
  #   for_each = var.users
  #   content {
  #     username       = user.key
  #     password       = random_password.user_password[user.key].result
  #     groups         = user.value.groups
  #     console_access = try(user.value.console_access, false)
  #   }
  # }

  tags = local.tags
}

resource "aws_sns_topic" "mq_alarms" {
  count = local.enable_mq_alerting ? 1 : 0

  name = "${local.name}-mq-alarms"
  tags = local.tags
}

data "archive_file" "mq_sns_to_telegram_zip" {
  count       = local.enable_mq_alerting ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/mq-sns-to-telegram.zip"

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

          safe_state   = html.escape(state_upper)
          safe_name    = html.escape(name)
          safe_region  = html.escape(region)
          safe_resource = html.escape(resource_id) if resource_id else ""
          safe_metric  = html.escape(str(metric)) if metric else ""
          safe_thresh  = html.escape(threshold_str) if threshold_str else ""
          safe_reason  = html.escape(short_reason)

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
              subject = sns.get("Subject", "Alarm")

              text = build_alarm_message(subject, raw_msg)
              send_to_telegram(text)

          return {"statusCode": 200}
      EOF

    filename = "lambda_function.py"
  }
}

resource "aws_iam_role" "mq_lambda_sns_to_telegram" {
  count = local.enable_mq_alerting ? 1 : 0

  name = "${local.name}-mq-sns-to-telegram-role"

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

resource "aws_iam_role_policy_attachment" "mq_lambda_basic" {
  count      = local.enable_mq_alerting ? 1 : 0
  role       = aws_iam_role.mq_lambda_sns_to_telegram[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "mq_sns_to_telegram" {
  count = local.enable_mq_alerting ? 1 : 0

  function_name = "${local.name}-mq-alarms-to-telegram"
  role          = aws_iam_role.mq_lambda_sns_to_telegram[0].arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"

  filename         = data.archive_file.mq_sns_to_telegram_zip[0].output_path
  source_code_hash = data.archive_file.mq_sns_to_telegram_zip[0].output_base64sha256

  timeout = 10

  environment {
    variables = {
      TELEGRAM_BOT_TOKEN = var.telegram_bot_token
      TELEGRAM_CHAT_ID   = var.telegram_chat_id
    }
  }
}

resource "aws_sns_topic_subscription" "mq_alarms_lambda" {
  count = local.enable_mq_alerting ? 1 : 0

  topic_arn = aws_sns_topic.mq_alarms[0].arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.mq_sns_to_telegram[0].arn
}

resource "aws_lambda_permission" "mq_sns_to_telegram" {
  count = local.enable_mq_alerting ? 1 : 0

  statement_id  = "AllowExecutionFromSNSMQAlarms"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.mq_sns_to_telegram[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.mq_alarms[0].arn
}

resource "aws_cloudwatch_metric_alarm" "mq_cpu_high" {
  count = local.enable_mq_alerting ? 1 : 0

  alarm_name          = "${local.name}-mq-cpu-high"
  alarm_description   = "Amazon MQ (RabbitMQ) CPU > ${var.mq_cpu_threshold}% for 10 minutes"
  namespace           = "AWS/AmazonMQ"
  metric_name         = "SystemCpuUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.mq_cpu_threshold

  dimensions = {
    Broker = aws_mq_broker.amazon_mq.broker_name
  }

  alarm_actions = [aws_sns_topic.mq_alarms[0].arn]
  ok_actions    = [aws_sns_topic.mq_alarms[0].arn]
}

resource "aws_cloudwatch_metric_alarm" "mq_mem_used_high" {
  count = local.enable_mq_alerting ? 1 : 0

  alarm_name          = "${local.name}-mq-mem-used-high"
  alarm_description   = "Amazon MQ (RabbitMQ) memory usage above threshold"
  namespace           = "AWS/AmazonMQ"
  metric_name         = "RabbitMQMemUsed"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.mq_mem_used_threshold_bytes

  dimensions = {
    Broker = aws_mq_broker.amazon_mq.broker_name
  }

  alarm_actions = [aws_sns_topic.mq_alarms[0].arn]
  ok_actions    = [aws_sns_topic.mq_alarms[0].arn]
}

resource "aws_cloudwatch_metric_alarm" "mq_disk_free_low" {
  count = local.enable_mq_alerting && var.enable_mq_disk_alarm ? 1 : 0

  alarm_name        = "${local.name}-mq-free-disk-low"
  alarm_description = "MQ free disk < (100 - mq_disk_usage_threshold_percent)% – disk usage high"

  namespace           = "AWS/AmazonMQ"
  metric_name         = "RabbitMQDiskFree"
  statistic           = "Average"
  period              = 300 # 5 minutes
  evaluation_periods  = 2   # 10 minutes total
  comparison_operator = "LessThanThreshold"
  threshold           = local.mq_disk_free_threshold_bytes

  treat_missing_data = "missing"

  dimensions = {
    Broker = aws_mq_broker.amazon_mq.broker_name
  }

  alarm_actions = [aws_sns_topic.mq_alarms[0].arn]
  ok_actions    = [aws_sns_topic.mq_alarms[0].arn]
}

resource "aws_cloudwatch_metric_alarm" "mq_connection_count_zero" {
  count = local.enable_mq_alerting ? 1 : 0

  alarm_name          = "${local.name}-mq-connections-zero"
  alarm_description   = "Amazon MQ (RabbitMQ) ConnectionCount == 0 for a prolonged period (approximate uptime check)"
  namespace           = "AWS/AmazonMQ"
  metric_name         = "ConnectionCount"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = var.mq_connection_zero_alarm_periods
  comparison_operator = "LessThanThreshold"
  threshold           = 1

  dimensions = {
    Broker = aws_mq_broker.amazon_mq.broker_name
  }

  alarm_actions = [aws_sns_topic.mq_alarms[0].arn]
  ok_actions    = [aws_sns_topic.mq_alarms[0].arn]
}
