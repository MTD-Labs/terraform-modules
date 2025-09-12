data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  name_prefix         = "${var.project_name}-${var.environment}"
  signing_secret_name = "${var.environment}-${var.project_name}-alchemy-signing-secret"

  common_tags = merge({
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.tags)
}

# --- Secrets Manager: look up Alchemy signing key ---
data "aws_secretsmanager_secret" "alchemy_signing_key" {
  name = local.signing_secret_name
}

# ---------------------------
# DLQ for Lambda failures (CRITICAL for data preservation)
# ---------------------------
resource "aws_sqs_queue" "webhook_dlq" {
  name                       = "${local.name_prefix}-webhook-dlq"
  message_retention_seconds  = 1209600 # 14 days (maximum)
  visibility_timeout_seconds = 300

  # Enable server-side encryption
  sqs_managed_sse_enabled = true

  tags = local.common_tags
}

resource "aws_sqs_queue_policy" "webhook_dlq_policy" {
  queue_url = aws_sqs_queue.webhook_dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.webhook_dlq.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_lambda_function.webhook.arn
          }
        }
      }
    ]
  })
}

# CloudWatch Alarm for DLQ
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${local.name_prefix}-webhook-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "Alert when messages are in webhook DLQ"
  treat_missing_data  = "notBreaching"

  dimensions = {
    QueueName = aws_sqs_queue.webhook_dlq.name
  }

  alarm_actions = var.sns_alert_topic_arn != "" ? [var.sns_alert_topic_arn] : []
  tags          = local.common_tags
}

# ---------------------------
# Security Groups
# ---------------------------

# SG for Lambda (egress-only; allow to broker and VPC endpoints)
resource "aws_security_group" "lambda_sg" {
  name        = "${local.name_prefix}-lambda-sg"
  description = "Lambda egress to RabbitMQ + VPC endpoints"
  vpc_id      = var.vpc_id
  tags        = local.common_tags

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SG for Amazon MQ broker
resource "aws_security_group" "mq_sg" {
  name        = "${local.name_prefix}-amq-sg"
  description = "Amazon MQ (RabbitMQ) broker"
  vpc_id      = var.vpc_id
  tags        = local.common_tags
}

# Allow AMQP over TLS from Lambda SG to Broker SG
resource "aws_security_group_rule" "mq_ingress_from_lambda" {
  type                     = "ingress"
  from_port                = 5671
  to_port                  = 5671
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mq_sg.id
  source_security_group_id = aws_security_group.lambda_sg.id
  description              = "AMQP/TLS from Lambda"
}

# Optional: Allow RabbitMQ Web Console access
resource "aws_security_group_rule" "mq_console_ingress" {
  count             = length(var.console_allowed_cidrs) > 0 ? 1 : 0
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.mq_sg.id
  cidr_blocks       = var.console_allowed_cidrs
  description       = "RabbitMQ Web Console access"
}

# SG for Interface VPC Endpoints
resource "aws_security_group" "vpce_sg" {
  name        = "${local.name_prefix}-vpce-sg"
  description = "Security group for interface VPC endpoints"
  vpc_id      = var.vpc_id
  tags        = local.common_tags

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group_rule" "vpce_ingress_from_lambda" {
  type                     = "ingress"
  description              = "From Lambda SG to VPC endpoints (HTTPS)"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpce_sg.id
  source_security_group_id = aws_security_group.lambda_sg.id
}

# ---------------------------
# VPC Endpoint service lookups
# ---------------------------
data "aws_vpc_endpoint_service" "secretsmanager" {
  service      = "secretsmanager"
  service_type = "Interface"
}

data "aws_vpc_endpoint_service" "ssm" {
  service      = "ssm"
  service_type = "Interface"
}

# ---------------------------
# VPC Interface Endpoints
# ---------------------------
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = var.vpc_id
  service_name        = data.aws_vpc_endpoint_service.secretsmanager.service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce_sg.id]
  subnet_ids          = var.vpc_private_subnet_ids
  tags                = local.common_tags
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = var.vpc_id
  service_name        = data.aws_vpc_endpoint_service.ssm.service_name
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.vpce_sg.id]
  subnet_ids          = var.vpc_private_subnet_ids
  tags                = local.common_tags
}
# ---------------------------
# Amazon MQ for RabbitMQ (PRODUCTION CONFIG)
# ---------------------------
resource "random_password" "admin_password" {
  length           = 40
  special          = true
  min_special      = 5
  override_special = "!#$%^&*()-_+[]{}<>?"
  keepers          = { pass_version = 1 }
}

resource "aws_ssm_parameter" "admin_password" {
  name        = "/${local.name_prefix}/rabbitmq/admin_password"
  description = "RabbitMQ admin password"
  type        = "SecureString"
  value       = random_password.admin_password.result
  key_id      = var.kms_ssm_key_arn != "" ? var.kms_ssm_key_arn : null
  tags        = local.common_tags
}

resource "random_password" "producer_password" {
  length           = 32
  special          = true
  min_special      = 5
  override_special = "!#$%^&*()-_+[]{}<>?"
  keepers          = { pass_version = 1 }
}

resource "aws_ssm_parameter" "producer_password" {
  name        = "/${local.name_prefix}/rabbitmq/producer_password"
  description = "RabbitMQ producer password"
  type        = "SecureString"
  value       = random_password.producer_password.result
  key_id      = var.kms_ssm_key_arn != "" ? var.kms_ssm_key_arn : null
  tags        = local.common_tags
}

resource "aws_mq_broker" "rabbit" {
  broker_name                = "${local.name_prefix}-rabbit"
  engine_type                = "RabbitMQ"
  engine_version             = var.mq_engine_version
  host_instance_type         = var.mq_instance_type
  deployment_mode            = var.mq_deployment_mode
  publicly_accessible        = false
  subnet_ids                 = var.mq_deployment_mode == "SINGLE_INSTANCE" ? [var.vpc_private_subnet_ids[0]] : var.vpc_private_subnet_ids
  security_groups            = [aws_security_group.mq_sg.id]
  authentication_strategy    = "SIMPLE"
  auto_minor_version_upgrade = true  # Control updates in production
  apply_immediately          = false # Apply changes during maintenance window
  tags                       = local.common_tags

  encryption_options {
    kms_key_id        = var.kms_mq_key_arn != "" ? var.kms_mq_key_arn : null
    use_aws_owned_key = var.kms_mq_key_arn == "" ? true : false
  }

  logs {
    general = true
  }

  maintenance_window_start_time {
    day_of_week = "SUNDAY"
    time_of_day = "03:00"
    time_zone   = "UTC"
  }

  user {
    username       = var.mq_admin_username
    password       = random_password.admin_password.result
    console_access = true
    groups         = ["admin"]
  }
}

# CloudWatch Alarms for RabbitMQ
resource "aws_cloudwatch_metric_alarm" "rabbitmq_cpu" {
  alarm_name          = "${local.name_prefix}-rabbitmq-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "SystemCpuUtilization"
  namespace           = "AWS/AmazonMQ"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "RabbitMQ CPU usage is too high"
  treat_missing_data  = "breaching"

  dimensions = {
    Broker = aws_mq_broker.rabbit.broker_name
  }

  alarm_actions = var.sns_alert_topic_arn != "" ? [var.sns_alert_topic_arn] : []
  tags          = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "rabbitmq_memory" {
  alarm_name          = "${local.name_prefix}-rabbitmq-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RabbitMQMemUsed"
  namespace           = "AWS/AmazonMQ"
  period              = "300"
  statistic           = "Average"
  threshold           = "3500000000" # ~3.5GB for m7g.medium
  alarm_description   = "RabbitMQ memory usage is too high"
  treat_missing_data  = "breaching"

  dimensions = {
    Broker = aws_mq_broker.rabbit.broker_name
  }

  alarm_actions = var.sns_alert_topic_arn != "" ? [var.sns_alert_topic_arn] : []
  tags          = local.common_tags
}

# ---------------------------
# Lambda packaging
# ---------------------------
resource "local_file" "lambda_function" {
  content  = file("${path.module}/lambda_src/index.mjs.tmpl")
  filename = "${path.module}/lambda_src/index.mjs"
}

resource "null_resource" "lambda_npm_install" {
  triggers = {
    index_hash   = filesha256("${path.module}/lambda_src/index.mjs.tmpl")
    package_hash = filesha256("${path.module}/lambda_src/package.json")
    lock_hash    = try(filesha256("${path.module}/lambda_src/package-lock.json"), "")
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/lambda_src"
    command     = "if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi"
    interpreter = ["bash", "-lc"]
  }
  depends_on = [local_file.lambda_function]
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_src"
  output_path = "${path.module}/lambda.zip"
  depends_on  = [local_file.lambda_function, null_resource.lambda_npm_install]
}

# ---------------------------
# IAM for Lambda
# ---------------------------
data "aws_iam_policy_document" "lambda_policy_base" {
  statement {
    sid     = "Logs"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [
      aws_cloudwatch_log_group.lambda.arn,
      "${aws_cloudwatch_log_group.lambda.arn}:*"
    ]
  }

  statement {
    sid       = "SecretsRead"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [data.aws_secretsmanager_secret.alchemy_signing_key.arn]
  }

  statement {
    sid     = "SsmRead"
    actions = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [
      aws_ssm_parameter.admin_password.arn,
      aws_ssm_parameter.producer_password.arn
    ]
  }

  # DLQ permissions
  statement {
    sid       = "DLQWrite"
    actions   = ["sqs:SendMessage", "sqs:GetQueueAttributes"]
    resources = [aws_sqs_queue.webhook_dlq.arn]
  }
}

data "aws_iam_policy_document" "lambda_policy_kms" {
  count = var.kms_ssm_key_arn != "" ? 1 : 0

  statement {
    sid       = "KmsDecrypt"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_ssm_key_arn]
  }
}

data "aws_iam_policy_document" "lambda_policy" {
  source_policy_documents = var.kms_ssm_key_arn != "" ? [
    data.aws_iam_policy_document.lambda_policy_base.json,
    data.aws_iam_policy_document.lambda_policy_kms[0].json
    ] : [
    data.aws_iam_policy_document.lambda_policy_base.json
  ]
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${local.name_prefix}-alchemy-webhook-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
  tags               = local.common_tags
}

resource "aws_iam_policy" "lambda_policy" {
  name   = "${local.name_prefix}-alchemy-webhook-policy"
  policy = data.aws_iam_policy_document.lambda_policy.json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ---------------------------
# CloudWatch logs
# ---------------------------
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.name_prefix}-alchemy-webhook"
  retention_in_days = 30 # Increased for production
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/apigw/${local.name_prefix}-alchemy-http"
  retention_in_days = 30 # Increased for production
  tags              = local.common_tags
}

# ---------------------------
# Lambda (PRODUCTION CONFIG)
# ---------------------------
resource "aws_lambda_function" "webhook" {
  function_name                  = "${local.name_prefix}-alchemy-webhook"
  role                           = aws_iam_role.lambda_exec.arn
  handler                        = "index.handler"
  runtime                        = "nodejs20.x"
  filename                       = data.archive_file.lambda_zip.output_path
  source_code_hash               = data.archive_file.lambda_zip.output_base64sha256
  timeout                        = 10  # Increased for reliability
  memory_size                    = 512 # Increased for better performance
  reserved_concurrent_executions = 100 # Prevent Lambda throttling

  vpc_config {
    subnet_ids         = var.vpc_private_subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  dead_letter_config {
    target_arn = aws_sqs_queue.webhook_dlq.arn
  }

  environment {
    variables = {
      # Webhook verification
      ALCHEMY_SIGNING_SECRET_ID = local.signing_secret_name
      EXPECTED_TOKEN            = random_uuid.webhook_token.result
      ALLOWED_IPS               = jsonencode(var.alchemy_source_ips)

      # RabbitMQ connection
      RABBITMQ_ENDPOINT = aws_mq_broker.rabbit.instances[0].endpoints[0]
      RABBITMQ_VHOST    = "/"
      RABBITMQ_USER     = var.mq_admin_username
      RABBITMQ_PASS_SSM = aws_ssm_parameter.admin_password.name
      RABBITMQ_QUEUE    = var.rabbitmq_queue_name

      # Enhanced settings
      ENABLE_PERSISTENCE_CHECK = "true"
      MAX_RETRY_ATTEMPTS       = "5"
      CONNECTION_TIMEOUT_MS    = "10000"
      DEBUG                    = var.environment != "prod" ? "true" : "false"

      RABBITMQ_QUEUE_TYPE = var.rabbitmq_queue_type
    }
  }

  logging_config {
    log_group  = aws_cloudwatch_log_group.lambda.name
    log_format = "JSON"
  }

  tags = local.common_tags
}

# Lambda error alarm
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${local.name_prefix}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Lambda function errors detected"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.webhook.function_name
  }

  alarm_actions = var.sns_alert_topic_arn != "" ? [var.sns_alert_topic_arn] : []
  tags          = local.common_tags
}

# Lambda throttles alarm
resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  alarm_name          = "${local.name_prefix}-lambda-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Lambda function throttled"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.webhook.function_name
  }

  alarm_actions = var.sns_alert_topic_arn != "" ? [var.sns_alert_topic_arn] : []
  tags          = local.common_tags
}

# ---------------------------
# API Gateway HTTP (v2)
# ---------------------------
resource "aws_apigatewayv2_api" "http" {
  name          = "${local.name_prefix}-alchemy-http"
  protocol_type = "HTTP"

  # CORS configuration if needed
  cors_configuration {
    allow_origins = ["https://webhook.site"] # Only for testing
    allow_methods = ["POST"]
    allow_headers = ["content-type", "x-alchemy-signature"]
    max_age       = 300
  }

  tags = local.common_tags
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.webhook.arn
  payload_format_version = "2.0"
  timeout_milliseconds   = 29000 # Maximum timeout
}

resource "aws_apigatewayv2_route" "post_webhook" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST ${var.webhook_path_prefix}/{token}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

# Add throttling to prevent abuse
resource "aws_apigatewayv2_stage" "api" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = var.api_stage_name
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = var.api_throttle_rate_limit
    throttling_burst_limit = var.api_throttle_burst_limit
  }


  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api.arn
    format = jsonencode({
      requestId      = "$context.requestId",
      requestTime    = "$context.requestTime",
      httpMethod     = "$context.httpMethod",
      path           = "$context.path",
      status         = "$context.status",
      sourceIp       = "$context.identity.sourceIp",
      responseLength = "$context.responseLength",
      error          = "$context.error.message",
      integrationErr = "$context.integrationErrorMessage"
    })
  }

  tags = local.common_tags
}

# API Gateway 4XX errors alarm
resource "aws_cloudwatch_metric_alarm" "api_4xx_errors" {
  alarm_name          = "${local.name_prefix}-api-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "API Gateway 4XX errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = aws_apigatewayv2_api.http.name
    Stage   = aws_apigatewayv2_stage.api.name
  }

  alarm_actions = var.sns_alert_topic_arn != "" ? [var.sns_alert_topic_arn] : []
  tags          = local.common_tags
}

# Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

# Token for unguessable URL
resource "random_uuid" "webhook_token" {}

# ---------------------------
# Backup Lambda for DLQ Processing (Optional but recommended)
# ---------------------------
resource "aws_lambda_function" "dlq_processor" {
  count            = var.enable_dlq_processor ? 1 : 0
  function_name    = "${local.name_prefix}-dlq-processor"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "dlq_processor.handler"
  runtime          = "nodejs20.x"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 60
  memory_size      = 256

  vpc_config {
    subnet_ids         = var.vpc_private_subnet_ids
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
    variables = {
      RABBITMQ_ENDPOINT   = aws_mq_broker.rabbit.instances[0].endpoints[0]
      RABBITMQ_VHOST      = "/"
      RABBITMQ_USER       = var.mq_admin_username
      RABBITMQ_PASS_SSM   = aws_ssm_parameter.admin_password.name
      RABBITMQ_QUEUE      = "${var.rabbitmq_queue_name}.retry"
      RABBITMQ_QUEUE_TYPE = var.rabbitmq_queue_type
    }
  }

  tags = local.common_tags
}

# Trigger DLQ processor every 5 minutes
resource "aws_cloudwatch_event_rule" "dlq_processor_schedule" {
  count               = var.enable_dlq_processor ? 1 : 0
  name                = "${local.name_prefix}-dlq-processor-schedule"
  description         = "Trigger DLQ processor"
  schedule_expression = "rate(5 minutes)"
  tags                = local.common_tags
}

resource "aws_cloudwatch_event_target" "dlq_processor_target" {
  count = var.enable_dlq_processor ? 1 : 0
  rule  = aws_cloudwatch_event_rule.dlq_processor_schedule[0].name
  arn   = aws_lambda_function.dlq_processor[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge_dlq" {
  count         = var.enable_dlq_processor ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dlq_processor[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.dlq_processor_schedule[0].arn
}