# aws_db_subnet_group
output "db_subnet_group_name" {
  description = "The db subnet group name"
  value       = module.aurora.*.db_subnet_group_name
}

# aws_rds_cluster
output "cluster_arn" {
  description = "Amazon Resource Name (ARN) of cluster"
  value       = module.aurora.*.cluster_arn
}

output "cluster_id" {
  description = "The RDS Cluster Identifier"
  value       = module.aurora.*.cluster_id
}

output "cluster_resource_id" {
  description = "The RDS Cluster Resource ID"
  value       = module.aurora.*.cluster_resource_id
}

output "cluster_members" {
  description = "List of RDS Instances that are a part of this cluster"
  value       = module.aurora.*.cluster_members
}

output "cluster_endpoint" {
  description = "Writer endpoint for the cluster"
  value       = module.aurora.*.cluster_endpoint
}

output "cluster_reader_endpoint" {
  description = "A read-only endpoint for the cluster, automatically load-balanced across replicas"
  value       = module.aurora.*.cluster_reader_endpoint
}

output "cluster_engine_version_actual" {
  description = "The running version of the cluster database"
  value       = module.aurora.*.cluster_engine_version_actual
}

# database_name is not set on `aws_rds_cluster` resource if it was not specified, so can't be used in output
output "cluster_database_name" {
  description = "Name for an automatically created database on cluster creation"
  value       = module.aurora.*.cluster_database_name
}

output "cluster_port" {
  description = "The database port"
  value       = module.aurora.*.cluster_port
}

output "cluster_master_password" {
  description = "The database master password"
  value       = module.aurora.*.cluster_master_password
  sensitive   = true
}

output "cluster_master_username" {
  description = "The database master username"
  value       = module.aurora.*.cluster_master_username
  sensitive   = true
}

output "cluster_hosted_zone_id" {
  description = "The Route53 Hosted Zone ID of the endpoint"
  value       = module.aurora.*.cluster_hosted_zone_id
}

# aws_rds_cluster_instances
output "cluster_instances" {
  description = "A map of cluster instances and their attributes"
  value       = module.aurora.*.cluster_instances
}

# aws_rds_cluster_endpoint
output "additional_cluster_endpoints" {
  description = "A map of additional cluster endpoints and their attributes"
  value       = module.aurora.*.additional_cluster_endpoints
}

# aws simple rds instance
output "rds_instance_arn" {
  description = "Amazon Resource Name (ARN) of RDS instance"
  value       = module.rds.*.db_instance_arn
}

output "rds_instance_address" {
  description = "Amazon Resource Name (ARN) of RDS instance"
  value       = module.rds.*.db_instance_address
}

output "rds_instance_endpoint" {
  description = "Amazon Resource Name (ARN) of RDS instance"
  value       = module.rds.*.db_instance_endpoint
}

output "rds_instance_master_password" {
  description = "The database master password"
  value       = random_password.master.result
  sensitive   = true
}

output "rds_instance_master_password_ssm_arn" {
  description = "The database master password ARN in Parameter Store"
  value       = aws_ssm_parameter.master_password.arn
}

output "rds_instance_master_username" {
  description = "The database master username"
  value       = module.rds.*.db_instance_username
  sensitive   = true
}

# output "db_user_passwords" {
#   description = "Map of DB user/passwords"
#   value = {
#     for user, role in postgresql_role.role : user => role.password
#   }
#   sensitive = true
# }

# output "db_connection_strings" {
#   description = "Map of DB connection strings"
#   value = {
#     for name, db in postgresql_database.db :
#     name =>
#     format("postgresql://%s:%s@%s:%s/%s", db.owner, postgresql_role.role[db.owner].password, module.aurora.*.cluster_endpoint, module.aurora.*.cluster_port, name)
#   }
#   sensitive = true
# }
