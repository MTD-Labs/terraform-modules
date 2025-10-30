variable "env" {
  type        = string
  description = "Environment name"
}

variable "name" {
  description = "Name used across resources created"
  type        = string
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Additional tags to apply to resources"
  default     = {}
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where DocumentDB will be deployed"
}

variable "vpc_subnets" {
  type        = list(string)
  description = "List of subnet IDs for DocumentDB"
}

variable "vpc_private_cidr_blocks" {
  type        = list(string)
  description = "List of private subnet CIDR blocks"
}

variable "engine_version" {
  description = "DocumentDB engine version"
  type        = string
  default     = "5.0.0"
}

variable "family" {
  description = "DocumentDB parameter group family"
  type        = string
  default     = "docdb5.0"
}

variable "instance_class" {
  description = "Instance class for DocumentDB instances"
  type        = string
  default     = "db.t3.medium"
}

variable "instance_count" {
  description = "Number of DocumentDB instances to create"
  type        = number
  default     = 1
}

variable "cluster_parameters" {
  description = "A map of parameters for DocumentDB cluster"
  type        = map(string)
  default = {
    tls                   = "enabled"
    ttl_monitor           = "enabled"
    audit_logs            = "disabled"
    profiler              = "disabled"
    profiler_threshold_ms = "100"
  }
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
  default     = ""
}

variable "backup_retention_period" {
  description = "The days to retain backups for"
  type        = number
  default     = 7
}

variable "preferred_maintenance_window" {
  description = "The weekly time range during which system maintenance can occur, in (UTC)"
  type        = string
  default     = "sun:03:00-sun:06:00"
}

variable "preferred_backup_window" {
  description = "The daily time range during which automated backups are created (UTC)"
  type        = string
  default     = "00:00-02:00"
}

variable "master_username" {
  description = "Master username for DocumentDB"
  type        = string
  default     = "docdbadmin"
}

variable "kms_ssm_key_arn" {
  type        = string
  description = "ARN of the AWS KMS key used for SSM encryption"
  default     = "alias/aws/ssm"
}

variable "kms_key_arn" {
  type        = string
  description = "ARN of the AWS KMS key used for DocumentDB encryption"
  default     = ""
}

variable "bastion_security_group_id" {
  description = "The security group ID of the bastion host to allow access to DocumentDB"
  type        = string
  default     = ""
}

variable "apply_immediately" {
  description = "Specifies whether any cluster modifications are applied immediately"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Determines whether a final snapshot is created before the cluster is deleted"
  type        = bool
  default     = false
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch. Valid values: audit, profiler"
  type        = list(string)
  default     = ["audit", "profiler"]
}

variable "deletion_protection" {
  description = "If the DB instance should have deletion protection enabled"
  type        = bool
  default     = true
}

variable "auto_minor_version_upgrade" {
  description = "Indicates that minor engine upgrades will be applied automatically"
  type        = bool
  default     = true
}
