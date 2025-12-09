variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "env" {
  type = string
}

variable "name" {
  description = "Name used across resources created"
  type        = string
  default     = ""
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vpc_id" {
  type = string
}

variable "vpc_subnets" {
  type = list(string)
}

variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/8"
}

variable "vpc_private_cidr_blocks" {
  type    = list(string)
  default = []
}

variable "allow_vpc_cidr_block" {
  description = "Allow full VPC CIDR block for access"
  type        = bool
  default     = false
}

variable "allow_vpc_private_cidr_blocks" {
  description = "Allow VPC private CIDR blocks for access"
  type        = bool
  default     = true
}

variable "extra_allowed_cidr_blocks" {
  description = "Extra allowed CIDR blocks"
  type        = string
  default     = "10.0.0.0/8"
}

variable "engine_type" {
  description = "Type of broker engine (ACTIVEMQ or RABBITMQ)"
  type        = string
  default     = "ACTIVEMQ"
}

variable "engine_version" {
  description = "The version of the broker engine"
  type        = string
  default     = "5.17.6"
}

variable "instance_type" {
  description = "The broker's instance type"
  type        = string
  default     = "mq.t3.micro"
}

variable "deployment_mode" {
  description = "The deployment mode of the broker (SINGLE_INSTANCE, ACTIVE_STANDBY_MULTI_AZ, CLUSTER_MULTI_AZ)"
  type        = string
  default     = "SINGLE_INSTANCE"
}

variable "auto_minor_version_upgrade" {
  description = "Enables automatic upgrades to new minor versions for brokers"
  type        = bool
  default     = false
}

variable "authentication_strategy" {
  description = "Authentication strategy for the broker (SIMPLE or LDAP)"
  type        = string
  default     = "simple"
}

variable "admin_username" {
  description = "Admin username for the broker"
  type        = string
  default     = "admin"
}

variable "users" {
  description = "Map of additional users and their configuration"
  type = map(object({
    groups         = list(string)
    console_access = optional(bool, false)
  }))
  default = {}
}

variable "enable_general_logging" {
  description = "Enables general logging via CloudWatch"
  type        = bool
  default     = false
}

variable "enable_audit_logging" {
  description = "Enables audit logging via CloudWatch"
  type        = bool
  default     = false
}

variable "maintenance_day_of_week" {
  description = "The day of the week for maintenance window"
  type        = string
  default     = "SUNDAY"
}

variable "maintenance_time_of_day" {
  description = "The time of day for maintenance window (format: HH:MM)"
  type        = string
  default     = "03:00"
}

variable "maintenance_time_zone" {
  description = "The time zone for maintenance window"
  type        = string
  default     = "UTC"
}

variable "kms_ssm_key_arn" {
  type        = string
  description = "ARN of the AWS KMS key used for SSM encryption"
  default     = "alias/aws/ssm"
}

variable "kms_mq_key_arn" {
  type        = string
  description = "ARN of the AWS KMS key used for MQ encryption"
  default     = null
}

variable "bastion_security_group_id" {
  description = "The security group ID of the bastion host to allow access to MQ"
  type        = string
}

variable "additional_security_group_ids" {
  description = "Additional security group IDs to allow access to MQ"
  type        = list(string)
  default     = []
}

variable "enable_mq_alarms" {
  description = "Enable CloudWatch -> SNS -> Telegram alerts for Amazon MQ"
  type        = bool
  default     = false
}

variable "mq_cpu_threshold" {
  description = "CPU utilization threshold for MQ alarm (%)"
  type        = number
  default     = 80
}

variable "mq_mem_used_threshold_bytes" {
  description = "RabbitMQMemUsed threshold in bytes"
  type        = number
  # ~2 GiB example
  default = 2147483648
}

variable "mq_disk_free_threshold_bytes" {
  description = "RabbitMQDiskFree low threshold in bytes"
  type        = number
  # ~10 GiB free
  default = 10737418240
}

variable "mq_connection_zero_alarm_periods" {
  description = "Number of 5-min periods with 0 connections before alarm"
  type        = number
  default     = 3
}

variable "telegram_bot_token" {
  description = "The security group ID of the bastion host to allow access to RDS"
  type        = string
  default     = "8572385599:AAHiXQwS5GM8WqFSVrePt8LehUe1cTmxCDg"
}

variable "telegram_chat_id" {
  description = "The security group ID of the bastion host to allow access to RDS"
  type        = string
  default     = "-1003423603621"
}

variable "enable_mq_disk_alarm" {
  description = "Enable Amazon MQ disk free space alarm"
  type        = bool
  default     = true
}

variable "mq_disk_total_gib" {
  description = "Total disk size allocated to the MQ broker in GiB (used for free-space threshold calculation)"
  type        = number
  default     = 100
}

variable "mq_disk_usage_threshold_percent" {
  description = "Disk usage percent at which alarm should fire. Example: 80 -> alarm when free < 20%."
  type        = number
  default     = 80
}
