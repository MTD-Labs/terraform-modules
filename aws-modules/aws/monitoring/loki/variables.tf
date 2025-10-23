variable "region" {
  type        = string
  description = "AWS region to deploy resources."
  default     = "eu-central-1"
}

variable "loki_bucket_name" {
  type        = string
  description = "Name of the S3 bucket for storing Loki logs."
  default     = ""
}

variable "account_id" {
  type        = string
  description = "AWS Account ID."
  default     = "712800952214"
}

variable "env" {
  type        = string
  description = "Deployment environment (e.g., dev, prod)."
  default     = "prod"
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

variable "cluster_oidc_id" {
  type        = string
  description = "OIDC domain part (e.g. oidc.eks.region.amazonaws.com/id/xxxx)"
}

variable "k8s_namespace" {
  type        = string
  description = "Kubernetes namespace for the Loki service account"
  default     = "loki"
}

variable "k8s_serviceaccount_name" {
  type        = string
  description = "Kubernetes service account name for Loki"
  default     = "loki"
}

variable "values_file_path" {
  type        = string
  description = "Loki Values Path"
  default     = null
}

variable "eks_enabled" {
  description = "Check for eks enabled"
  type        = bool
  default     = false
}
