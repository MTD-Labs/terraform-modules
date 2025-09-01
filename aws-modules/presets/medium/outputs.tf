output "ecs_task_exec_role_name" {
  description = "ECS task execution role name"
  value       = module.ecs[0].ecs_task_exec_role_name
}
