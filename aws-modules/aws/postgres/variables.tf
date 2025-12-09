variable "region" {
  type    = string
  default = "ap-south-1"
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
  default = null
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
  type = list(string)
}

variable "vpc_subnet_group_name" {
  type    = string
  default = "database-subnet-group"
}

variable "rds_type" {
  description = "Simple RDS or Aurora"
  type        = string
  default     = "rds"
}

variable "engine_version" {
  description = "Engine version"
  type        = string
  default     = "15.5"
}

variable "family" {
  description = "Engine family"
  type        = string
  default     = "postgres15"
}

variable "instance_class" {
  description = "Instance class used"
  type        = string
  default     = "db.t3.medium"
}

variable "allocated_storage" {
  description = "Storage amount for DB"
  type        = number
  default     = 10
}

variable "max_allocated_storage" {
  description = "Maximum storage amount for DB (enables autoscaling), 0 is disabled"
  type        = number
  default     = 0
}

variable "rds_cluster_parameters" {
  description = "A map of parameters for RDS Aurora cluster, if applicable"
  type        = map(string)
  default     = {}
}

variable "rds_db_parameters" {
  description = "A map of parameters for RDS database instances, if applicable"
  type        = map(string)
  default     = {}
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
  description = "extra allowed cidr blocks"
  type        = string
  default     = "10.0.0.0/8"
}

variable "backup_retention_period" {
  description = "The days to retain backups for"
  type        = number
  default     = 7
}

variable "preferred_maintenance_window" {
  description = "The weekly time range during which system maintenance can occur, in (UTC)"
  type        = string
  default     = "Sat:00:00-Sat:03:00"
}

variable "preferred_backup_window" {
  description = "The daily time range during which automated backups are created if automated backups are enabled using the `backup_retention_period` parameter. Time in UTC"
  type        = string
  default     = "03:00-06:00"
}

variable "master_username" {
  description = "master username"
  type        = string
  default     = "postgres"
}

variable "database_name" {
  description = "Database name to create initially"
  type        = string
  default     = "laravel"
}

variable "kms_ssm_key_arn" {
  type        = string
  description = "ARN of the AWS KMS key used for SSM encryption"
  default     = "alias/aws/ssm"
}

variable "database_user_map" {
  type        = map(string)
  description = "Map of databases and their users to create in RDS instance"
  default     = {}
}

variable "bastion_security_group_id" {
  description = "The security group ID of the bastion host to allow access to RDS"
  type        = string
}

variable "enable_rds_alarms" {
  description = "Enable CloudWatch + SNS + Lambda alerts for RDS"
  type        = bool
  default     = false
}

variable "rds_cpu_threshold" {
  description = "CPUUtilization alarm threshold (%)"
  type        = number
  default     = 80
}

variable "rds_free_memory_threshold_bytes" {
  description = "FreeableMemory alarm threshold in bytes"
  type        = number
  default     = 2147483648
}

variable "rds_event_categories" {
  description = "RDS event categories to subscribe to"
  type        = list(string)
  default = [
    "availability",
    "deletion",
    "failover",
    "failure",
    "maintenance",
    "recovery",
    "restoration"
  ]
}

variable "telegram_bot_token" {
  description = "The security group ID of the bastion host to allow access to RDS"
  type        = string
  default     = "8259402077:AAGIbM_McpV7Yuc-vEtDUZeAQ2CVH0AXPq8"
}

variable "telegram_chat_id" {
  description = "The security group ID of the bastion host to allow access to RDS"
  type        = string
  default     = "-1003423603621"
}

variable "enable_rds_storage_alarm" {
  description = "Enable RDS storage (disk usage) alarm"
  type        = bool
  default     = true
}

variable "rds_storage_usage_threshold_percent" {
  description = "Usage percentage at which to alarm for RDS disk (e.g. 80 => alarm when used >= 80%, i.e. free <= 20%)"
  type        = number
  default     = 80
}
