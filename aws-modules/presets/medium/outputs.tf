output "ecs_task_exec_role_name" {
  description = "ECS task execution role name"
  value       = var.ecs_enabled ? module.ecs[0].ecs_task_exec_role_name : null
}
