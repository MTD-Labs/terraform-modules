variable "region" {
  description = "AWS region"
  type        = string
}

variable "install_external_secrets" {
  description = "Whether to install External Secrets Operator"
  type        = bool
  default     = true
}

variable "external_secrets_chart_version" {
  description = "Helm chart version for External Secrets Operator"
  type        = string
  default     = "0.9.11"
}

variable "external_secrets_role_arn" {
  description = "IAM Role ARN for External Secrets Operator IRSA"
  type        = string
}

variable "cluster_ready_dependency" {
  description = "Dependency to ensure cluster is ready before installing"
  type        = any
  default     = null
}

variable "create_secret_store" {
  description = "Whether to create a default SecretStore"
  type        = bool
  default     = true
}

variable "secret_store_name" {
  description = "Name of the SecretStore"
  type        = string
  default     = "aws-secrets-manager"
}

variable "secret_store_namespace" {
  description = "Namespace for the SecretStore"
  type        = string
  default     = "default"
}

variable "create_cluster_secret_store" {
  description = "Whether to create a ClusterSecretStore (cluster-wide access)"
  type        = bool
  default     = true
}

variable "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore"
  type        = string
  default     = "aws-secrets-manager-cluster"
}
