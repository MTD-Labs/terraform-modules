output "id" {
  value       = module.redis.id
  description = "Redis cluster ID"
}

output "port" {
  value       = module.redis.port
  description = "Redis port"
}

output "endpoint" {
  value       = module.redis.endpoint
  description = "Redis primary or configuration endpoint, whichever is appropriate for the given cluster mode"
}

output "reader_endpoint_address" {
  value       = module.redis.reader_endpoint_address
  description = "The address of the endpoint for the reader node in the replication group, if the cluster mode is disabled."
}

output "member_clusters" {
  value       = module.redis.member_clusters
  description = "Redis cluster members"
}

output "host" {
  value       = module.redis.host
  description = "Redis hostname"
}

output "arn" {
  value       = module.redis.arn
  description = "Elasticache Replication Group ARN"
}

output "auth_token" {
  value     = random_password.auth_token.result
  sensitive = true
}

output "auth_token_ssm_arn" {
  value = aws_ssm_parameter.auth_token.arn
}