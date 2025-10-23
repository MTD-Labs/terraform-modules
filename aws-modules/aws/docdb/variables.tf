variable "region" {
  type    = string
  default = "me-south-1"
}

variable "env" {
  type = string
}

variable "name" {
  description = "Name suffix used across resources"
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
  description = "(Unused directly here; you likely used these to build the subnet group outside)"
  type        = list(string)
}

variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/8"
}

variable "vpc_private_cidr_blocks" {
  type = list(string)
}

variable "vpc_subnet_group_name" {
  description = "Existing DB subnet group name for DocumentDB"
  type        = string
  default     = "database-subnet-group"
}

# ---- Access control, same pattern as Postgres module ----
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

variable "bastion_security_group_id" {
  description = "Security group ID of bastion host to allow access"
  type        = string
}

# ---- Engine / sizing ----
variable "engine_version" {
  description = "DocumentDB engine version (e.g., 5.0, 4.0)"
  type        = string
  default     = "5.0"
}

variable "family" {
  description = "DocumentDB family for parameter group (e.g., docdb5.0)"
  type        = string
  default     = "docdb5.0"
}

variable "instance_class" {
  description = "Instance class for the cluster instances"
  type        = string
  default     = "db.t3.medium"
}

variable "instances_count" {
  description = "Number of instances in the cluster"
  type        = number
  default     = 1
}

# ---- Windows / retention ----
variable "backup_retention_period" {
  description = "Days to retain backups"
  type        = number
  default     = 7
}

variable "preferred_maintenance_window" {
  description = "Weekly maintenance window in UTC, e.g. Sat:00:00-Sat:03:00"
  type        = string
  default     = "Sat:00:00-Sat:03:00"
}

variable "preferred_backup_window" {
  description = "Daily backup window in UTC, e.g. 03:00-06:00"
  type        = string
  default     = "03:00-06:00"
}

# ---- Auth / KMS ----
variable "master_username" {
  description = "Master username"
  type        = string
  default     = "docdb"
}

variable "default_database" {
  description = "Database part used in sample connection URIs"
  type        = string
  default     = "admin"
}

variable "kms_ssm_key_arn" {
  description = "KMS key ARN for SSM parameter encryption"
  type        = string
  default     = "alias/aws/ssm"
}

variable "kms_key_id" {
  description = "Optional KMS key ARN for DocumentDB storage encryption"
  type        = string
  default     = null
}

# ---- Flags ----
variable "deletion_protection" {
  type    = bool
  default = false
}

variable "skip_final_snapshot" {
  type    = bool
  default = false
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of enabled log exports (supported: [\"audit\"])"
  type        = list(string)
  default     = []
}

# ---- Cluster parameters ----
variable "docdb_cluster_parameters" {
  description = "Map of cluster parameters to set"
  type        = map(string)
  default     = {}
}
