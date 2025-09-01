output "vpc_id" {
  description = "AWS VPC id."
  value       = module.vpc.vpc_id
}

output "region" {
  description = "AWS region."
  value       = var.region
}

output "env" {
  description = "env"
  value       = var.env
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "public_subnets" {
  description = "public subnets ids"
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "private subnets ids"
  value       = module.vpc.private_subnets
}

output "elasticache_subnets" {
  description = "elasticache subnets ids"
  value       = module.vpc.elasticache_subnets
}

output "database_subnets" {
  description = "database subnets ids"
  value       = module.vpc.database_subnets
}

output "database_subnet_group_name" {
  description = "Name of database subnet group"
  value       = module.vpc.database_subnet_group_name
}

output "public_subnets_cidr_blocks" {
  description = "List of cidr_blocks of public subnets"
  value       = module.vpc.public_subnets_cidr_blocks
}

output "private_subnets_cidr_blocks" {
  description = "List of cidr_blocks of private subnets"
  value       = module.vpc.private_subnets_cidr_blocks
}

output "elasticache_subnets_cidr_blocks" {
  description = "List of cidr_blocks of elasticache subnets"
  value       = module.vpc.elasticache_subnets_cidr_blocks
}

output "database_subnets_cidr_blocks" {
  description = "List of cidr_blocks of database subnets"
  value       = module.vpc.database_subnets_cidr_blocks
}

output "public_route_table_ids" {
  description = "List of IDs of public route tables"
  value       = module.vpc.public_route_table_ids
}

output "private_route_table_ids" {
  description = "List of IDs of private route tables"
  value       = module.vpc.private_route_table_ids
}

output "elasticache_route_table_ids" {
  description = "List of IDs of elasticache route tables"
  value       = module.vpc.elasticache_route_table_ids
}

output "elasticache_subnet_group_name" {
  description = "Name of elasticache subnet group"
  value       = module.vpc.elasticache_subnet_group_name
}

output "database_route_table_ids" {
  description = "List of IDs of database route tables"
  value       = module.vpc.database_route_table_ids
}

output "vpc_cidr_block" {
  description = "Cidr block of VPC"
  value       = module.vpc.vpc_cidr_block
}
