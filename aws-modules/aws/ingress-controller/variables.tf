variable "env" {
  type        = string
  description = "Deployment environment (e.g., dev, prod)."
  default     = "prod"
}

variable "values_file_path" {
  type        = string
  description = "grafana Values Path"
  default     = null
}

variable "cluster_endpoint" {
  type    = string
  default = ""
}

variable "cluster_ca_cert" {
  type    = string
  default = ""
}

variable "cluster_name" {
  type    = string
  default = null
}

variable "host" {
  type    = string
  default = null
}

variable "acm_arn" {
  type    = string
  default = null
}

variable "subnets" {
  type    = list(string)
  default = []
}

variable "security_groups" {
  description = "K8s Nodes SG IDs"
  type        = list(string)
  default     = []
}

variable "domain_name" {
  description = "The domain name for the project"
  type        = string
  default     = "example.com"
}

variable "eks_enabled" {
  description = "Check for eks enabled"
  type        = bool
  default     = false
}
