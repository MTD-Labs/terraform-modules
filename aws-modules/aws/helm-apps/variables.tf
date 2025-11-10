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

variable "app_name" {
  type    = string
  default = null
}


variable "namespace" {
  type    = string
  default = null
}

variable "chart_name" {
  type    = string
  default = null
}

variable "chart_version" {
  type    = string
  default = null
}

variable "region" {
  type    = string
  default = null
}
