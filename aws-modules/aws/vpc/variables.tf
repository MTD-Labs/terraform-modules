variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "env" {
  type    = string
  default = null
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.0.0.0/20", "10.0.16.0/20", "10.0.32.0/20"]
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.0.64.0/20", "10.0.80.0/20", "10.0.96.0/20"]
}

variable "elasticache_subnets" {
  type    = list(string)
  default = ["10.0.112.0/20", "10.0.128.0/20", "10.0.144.0/20"]
}

variable "elasticache_subnet_group_name" {
  description = "Name of elasticache subnet group"
  type        = string
  default     = null
}
variable "database_subnets" {
  type    = list(string)
  default = ["10.0.160.0/20", "10.0.176.0/20", "10.0.192.0/20"]
}

variable "database_subnet_group_name" {
  description = "Name of database subnet group"
  type        = string
  default     = null
}

variable "logging_subnets" {
  type    = list(string)
  default = ["10.0.208.0/20", "10.0.224.0/20", "10.0.240.0/20"]
}

variable "logging_subnet_group_name" {
  description = "Name of logging subnet group"
  type        = string
  default     = null
}

variable "enable_nat_gateway" {
  type        = bool
  default     = false
  description = "Should be true if you want to provision NAT Gateways for each of your private networks"
}

variable "single_nat_gateway" {
  type        = bool
  default     = true
  description = "Should be true if you want to provision a single shared NAT Gateway across all of your private networks"
}

variable "enable_dns_hostnames" {
  type        = bool
  default     = true
  description = "Should be true to enable DNS hostnames in the VPC"
}

variable "enable_dns_support" {
  type        = bool
  default     = true
  description = "Should be true to enable DNS support in the VPC"
}

variable "postgres_enabled" {
  type        = bool
  default     = false
  description = ""
}

variable "ecs_enabled" {
  type        = bool
  default     = false
  description = ""
}
