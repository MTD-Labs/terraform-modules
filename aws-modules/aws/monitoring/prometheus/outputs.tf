output "prometheus_release_name" {
  description = "The name of the Prometheus Helm release"
  value       = var.eks_enabled ? helm_release.prometheus[0].name : null
}

output "prometheus_namespace" {
  description = "The namespace where Prometheus is deployed"
  value       = var.eks_enabled ? helm_release.prometheus[0].namespace : null
}

output "prometheus_chart_version" {
  description = "The version of the Prometheus chart deployed"
  value       = var.eks_enabled ? helm_release.prometheus[0].version : null
}

output "prometheus_status" {
  description = "Status of the Prometheus Helm release"
  value       = var.eks_enabled ? helm_release.prometheus[0].status : null
}
