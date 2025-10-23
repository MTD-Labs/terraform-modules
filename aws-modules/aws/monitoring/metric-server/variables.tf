variable "tenant_id" {
  type        = string
  description = "Tenant ID for Promtail"
  default     = null
}

variable "env" {
  type        = string
  description = "Deployment environment (e.g., dev, prod)."
  default     = "prod"
}

variable "values_file_path" {
  type        = string
  description = "Promtail Values Path"
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

variable "eks_enabled" {
  description = "Check for eks enabled"
  type        = bool
  default     = false
}
