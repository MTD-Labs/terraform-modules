
########################################
# OUTPUTS (NEW) — for your Loki module
########################################

output "cluster_oidc_issuer" {
  description = "Full OIDC issuer URL"
  value       = local.oidc_issuer
}

output "cluster_oidc_id" {
  description = "OIDC ID (the trailing part after /id/)"
  value       = local.oidc_id
}

output "cluster_oidc_hostpath" {
  description = "Issuer host+path without https:// (useful for trust policy conditions)"
  value       = local.oidc_hostpath
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN to pass into external modules (e.g., Loki trust policy)"
  value       = aws_iam_openid_connect_provider.eks.arn
}
