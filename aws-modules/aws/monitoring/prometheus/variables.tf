variable "env" {
  description = "Environment name"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "cluster_ca_cert" {
  description = "EKS cluster CA certificate"
  type        = string
}

variable "values_file_path" {
  description = "Path to the Helm values file"
  type        = string
}

variable "subnets" {
  description = "List of subnet IDs for the load balancer"
  type        = list(string)
}

variable "eks_enabled" {
  description = "Whether EKS is enabled"
  type        = bool
  default     = false
}
