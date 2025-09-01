output "security_group_id" {
  value       = aws_security_group.ecs_monitor.id
  description = "ECS Monitor stack security group ID"
}
