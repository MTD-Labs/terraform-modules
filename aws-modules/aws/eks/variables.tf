variable "region" {
  description = "AWS region"
  type        = string
}

variable "env" {
  description = "Environment (e.g., dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "Additional resource tags"
  type        = map(string)
  default     = {}
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the cluster"
  type        = string
}

variable "vpc_subnets" {
  description = "Subnet IDs for the cluster"
  type        = list(string)
}

variable "vpc_private_cidr_blocks" {
  description = "Private CIDR blocks for security group ingress"
  type        = list(string)
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "instance_types" {
  description = "List of EC2 instance types for the node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of nodes"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes"
  type        = number
  default     = 5
}

variable "service_ipv4_cidr" {
  description = "CIDR block for Kubernetes service IPs"
  type        = string
  default     = "172.20.0.0/16"
}

variable "endpoint_private" {
  description = "Enable private endpoint access"
  type        = bool
  default     = true
}

variable "endpoint_public" {
  description = "Enable public endpoint access"
  type        = bool
  default     = true
}

variable "enabled_logs" {
  description = "Which control plane logs to enable (API, audit, etc.)"
  type        = list(string)
  default     = ["api", "audit", "authenticator"]
}

variable "domain_name" {
  description = "The domain name for the project"
  type        = string
  default     = "example.com"
}
