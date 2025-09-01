output "alb_id" {
  value       = var.ecs_enabled ? aws_alb.alb[0].id : null
  description = "Application Load Balancer ID"
}

output "alb_aws_security_group_id" {
  value       = var.ecs_enabled ? aws_security_group.alb[0].id : null
  description = "Security Group ID associated with the Application Load Balancer"
}

output "alb_listener_https_arn" {
  value       = var.ecs_enabled ? aws_alb_listener.alb_default_listener_https[0].arn : null
  description = "Application Load Balancer HTTPS Listener ARN"
}

output "alb_listener_http_arn" {
  value       = var.ecs_enabled ? aws_alb_listener.alb_default_listener_http[0].arn : null
  description = "Application Load Balancer HTTP Listener ARN"
}

output "alb_certificate_arn" {
  value       = var.ecs_enabled ? aws_acm_certificate.alb_certificate[0].arn : null
  description = "ARN of the ACM certificate used by the Application Load Balancer"
}
