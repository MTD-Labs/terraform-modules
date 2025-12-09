variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "env" {
  type = string
}

variable "name" {
  type    = string
  default = null
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

variable "vpc_subnet_group_name" {
  type    = string
  default = "elasticache-subnet-group"
}

variable "cluster_size" {
  description = "Redis number of nodes in cluster"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "Elastic cache instance type"
  type        = string
  default     = "cache.t2.micro"
}

variable "engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0"
}

variable "family" {
  description = "Redis family"
  type        = string
  default     = "redis7"
}

variable "cluster_mode_num_node_groups" {
  description = "Number of node groups (shards) for this Redis replication group. Changing this number will trigger an online resizing operation before other settings modifications"
  type        = number
  default     = 0
}

variable "cluster_mode_enabled" {
  description = "Redis cluster mode enabled"
  type        = bool
  default     = false
}

variable "automatic_failover_enabled" {
  description = "Redis automatic failover enabled"
  type        = bool
  default     = false
}

variable "cluster_mode_replicas_per_node_group" {
  description = "Redis cluster mode replicas per node group"
  type        = number
  default     = 0
}

variable "snapshot_retention_limit" {
  description = "The number of days for which ElastiCache will retain automatic cache cluster snapshots"
  type        = number
  default     = 7
}

variable "snapshot_window" {
  description = "The daily time range (in UTC) during which ElastiCache will begin taking a daily snapshot"
  type        = string
  default     = "04:00-05:00"
}

variable "kms_ssm_key_arn" {
  type        = string
  description = "ARN of the AWS KMS key used for SSM encryption"
  default     = "alias/aws/ssm"
}

variable "enable_redis_alarms" {
  type        = bool
  default     = true
  description = "Enable CloudWatch + Telegram alerts for Redis"
}

variable "redis_cpu_threshold" {
  type        = number
  default     = 70
}

variable "redis_node_max_memory_bytes" {
  type        = number
  description = "Total usable Redis memory per node (bytes)"
}

variable "redis_memory_usage_threshold_percent" {
  type        = number
  default     = 80
}

variable "telegram_bot_token" {
  type        = string
  description = "Telegram bot token used for sending Redis alarms"
  default = "8517142733:AAHH1XVe70JlPWRaIOl_BVF4hBv_7YpfYR8"
}

variable "telegram_chat_id" {
  description = "The security group ID of the bastion host to allow access to RDS"
  type        = string
  default     = "-1003423603621"
}