# ----------------------------
# Core
# ----------------------------
variable "project_name" {
  description = "Project/system name used in resource naming."
  type        = string
  default     = "trendex"
}

variable "environment" {
  description = "Environment name (e.g., prod, stage, dev)."
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "eu-central-1"
}

variable "tags" {
  description = "Common resource tags to apply to all resources."
  type        = map(string)
  default     = {}
}

# ----------------------------
# Monitoring & Alerting
# ----------------------------
variable "sns_alert_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms. Leave empty to disable alerting."
  type        = string
  default     = ""
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring for all resources."
  type        = bool
  default     = true
}

# ----------------------------
# API / Lambda
# ----------------------------
variable "webhook_path_prefix" {
  description = "Base path segment for the webhook route."
  type        = string
  default     = "/alchemy"
}

variable "lambda_memory_mb" {
  description = "Lambda memory (MB). Higher memory = better performance."
  type        = number
  default     = 256 # Increased for production

  validation {
    condition     = var.lambda_memory_mb >= 128 && var.lambda_memory_mb <= 10240
    error_message = "Lambda memory must be between 128 and 10240 MB."
  }
}

variable "lambda_timeout_seconds" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 10 # Increased for reliability

  validation {
    condition     = var.lambda_timeout_seconds >= 1 && var.lambda_timeout_seconds <= 900
    error_message = "Lambda timeout must be between 1 and 900 seconds."
  }
}

variable "lambda_reserved_concurrency" {
  description = "Reserved concurrent executions for Lambda. Set to -1 for no limit."
  type        = number
  default     = 100

  validation {
    condition     = var.lambda_reserved_concurrency == -1 || (var.lambda_reserved_concurrency >= 1 && var.lambda_reserved_concurrency <= 1000)
    error_message = "Reserved concurrency must be -1 (unlimited) or between 1 and 1000."
  }
}

variable "api_stage_name" {
  description = "API Gateway stage name."
  type        = string
  default     = "prod"
}

variable "api_throttle_rate_limit" {
  description = "API Gateway throttle rate limit (requests per second)."
  type        = number
  default     = 1000
}

variable "api_throttle_burst_limit" {
  description = "API Gateway throttle burst limit."
  type        = number
  default     = 2000
}

# ----------------------------
# DLQ & Retry Configuration
# ----------------------------
variable "enable_dlq" {
  description = "Enable Dead Letter Queue for failed webhook processing."
  type        = bool
  default     = true # CRITICAL for production
}

variable "dlq_message_retention_days" {
  description = "DLQ message retention in days (1-14)."
  type        = number
  default     = 14

  validation {
    condition     = var.dlq_message_retention_days >= 1 && var.dlq_message_retention_days <= 14
    error_message = "DLQ retention must be between 1 and 14 days."
  }
}

variable "enable_dlq_processor" {
  description = "Enable automated DLQ processor Lambda for retry logic."
  type        = bool
  default     = false # Recommended for production
}

variable "dlq_processor_schedule" {
  description = "Schedule expression for DLQ processor (e.g., 'rate(5 minutes)')."
  type        = string
  default     = "rate(5 minutes)"
}

# ----------------------------
# Networking / VPC
# ----------------------------
variable "vpc_id" {
  description = "VPC ID where RabbitMQ and the Lambda will run."
  type        = string
  default     = "vpc-0abcea947f1d04c20"
}

variable "vpc_private_subnet_ids" {
  description = "Private subnet IDs for the broker and Lambda (2–3 for multi-AZ)."
  type        = list(string)
  default     = ["subnet-0af765e6a2fb83409"]
}

variable "console_allowed_cidrs" {
  description = "Optional CIDRs allowed to access the RabbitMQ web console (port 443). Leave empty to disable."
  type        = list(string)
  default     = ["172.31.32.0/20"]
}

# ----------------------------
# Amazon MQ (RabbitMQ)
# ----------------------------
variable "mq_engine_version" {
  description = "RabbitMQ engine version supported in your region."
  type        = string
  default     = "3.13"
}

variable "mq_instance_type" {
  description = "Amazon MQ for RabbitMQ broker instance type."
  type        = string
  default     = "mq.m7g.medium"

  # Production recommendations:
  # - mq.m7g.medium: ~$0.30/hour for SINGLE_INSTANCE (good for up to 1000 msg/sec)
  # - mq.m7g.large: ~$0.60/hour for better performance
  # - For HA: Use CLUSTER_MULTI_AZ with 3 nodes
}

variable "mq_deployment_mode" {
  description = "Broker deployment mode: SINGLE_INSTANCE, CLUSTER_MULTI_AZ (3 nodes), or ACTIVE_STANDBY_MULTI_AZ."
  type        = string
  default     = "SINGLE_INSTANCE" # Change to CLUSTER_MULTI_AZ for production HA

  validation {
    condition     = contains(["SINGLE_INSTANCE", "ACTIVE_STANDBY_MULTI_AZ", "CLUSTER_MULTI_AZ"], var.mq_deployment_mode)
    error_message = "mq_deployment_mode must be one of: SINGLE_INSTANCE, ACTIVE_STANDBY_MULTI_AZ, CLUSTER_MULTI_AZ."
  }
}

variable "mq_admin_username" {
  description = "RabbitMQ admin username."
  type        = string
  default     = "trendex-admin"
}

variable "mq_users" {
  description = "Additional RabbitMQ users (map of objects). Example: { app = { groups = [], console_access = true } }"
  type = map(object({
    groups         = list(string)
    console_access = optional(bool)
  }))
  default = {}
}

variable "mq_auto_minor_version_upgrade" {
  description = "Enable automatic minor version upgrades during maintenance window."
  type        = bool
  default     = false # Control updates in production
}

variable "mq_apply_immediately" {
  description = "Apply configuration changes immediately (true) or during maintenance window (false)."
  type        = bool
  default     = false # Always use maintenance window in production
}

# ----------------------------
# KMS keys (optional)
# ----------------------------
variable "kms_ssm_key_arn" {
  description = "KMS key ARN to encrypt SSM SecureString parameters. Leave empty to use AWS managed key."
  type        = string
  default     = ""
}

variable "kms_mq_key_arn" {
  description = "KMS key ARN for Amazon MQ broker encryption. Leave empty to use AWS owned CMK."
  type        = string
  default     = ""
}

variable "kms_sqs_key_arn" {
  description = "KMS key ARN for SQS DLQ encryption. Leave empty to use AWS managed key."
  type        = string
  default     = ""
}

# ----------------------------
# Security (API allowlist)
# ----------------------------
variable "alchemy_source_ips" {
  description = "Static IPs allowed to call API Gateway (Alchemy egress IPs)."
  type        = list(string)
  default = [
    "54.236.136.17/32",
    "34.237.24.169/32",
    "87.241.157.116/32",
  ]
}

# ----------------------------
# RabbitMQ Configuration
# ----------------------------
variable "rabbitmq_queue_name" {
  description = "Durable RabbitMQ queue name to publish webhook events to."
  type        = string
  default     = "alchemy.events"
}

variable "rabbitmq_queue_type" {
  description = "RabbitMQ queue type: 'quorum' (recommended for HA) or 'classic'."
  type        = string
  default     = "classic"

  validation {
    condition     = contains(["quorum", "classic", ""], var.rabbitmq_queue_type)
    error_message = "Queue type must be 'quorum', 'classic', or empty string."
  }
}

variable "rabbitmq_max_retry_attempts" {
  description = "Maximum retry attempts for RabbitMQ publishing."
  type        = number
  default     = 5
}

variable "rabbitmq_connection_timeout_ms" {
  description = "RabbitMQ connection timeout in milliseconds."
  type        = number
  default     = 10000
}

# ----------------------------
# Logging & Debugging
# ----------------------------
variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_days)
    error_message = "Log retention must be a valid CloudWatch value."
  }
}

variable "enable_debug_logging" {
  description = "Enable debug logging in Lambda functions."
  type        = bool
  default     = false # Set to true only for troubleshooting
}

# ----------------------------
# Backup & Recovery
# ----------------------------
variable "enable_backup" {
  description = "Enable AWS Backup for RabbitMQ broker."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Backup retention period in days."
  type        = number
  default     = 7
}

variable "backup_schedule" {
  description = "Backup schedule in cron format."
  type        = string
  default     = "cron(0 3 * * ? *)" # Daily at 3 AM UTC
}
