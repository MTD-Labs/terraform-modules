output "ecs_task_exec_role_name" {
  description = "ECS task execution role name"
  value       = aws_iam_role.exec_role.name
}

output "ecs_task_role_name" {
  description = "ECS task role name"
  value       = aws_iam_role.task_role.name
}