# DocumentDB Cluster outputs
output "cluster_arn" {
  description = "Amazon Resource Name (ARN) of the DocumentDB cluster"
  value       = aws_docdb_cluster.docdb.arn
}

output "cluster_id" {
  description = "The DocumentDB Cluster Identifier"
  value       = aws_docdb_cluster.docdb.id
}

output "cluster_resource_id" {
  description = "The DocumentDB Cluster Resource ID"
  value       = aws_docdb_cluster.docdb.cluster_resource_id
}

output "cluster_endpoint" {
  description = "Endpoint for the DocumentDB cluster"
  value       = aws_docdb_cluster.docdb.endpoint
}

output "cluster_reader_endpoint" {
  description = "A read-only endpoint for the DocumentDB cluster"
  value       = aws_docdb_cluster.docdb.reader_endpoint
}

output "cluster_port" {
  description = "The DocumentDB port"
  value       = aws_docdb_cluster.docdb.port
}

output "cluster_members" {
  description = "List of DocumentDB instances that are part of this cluster"
  value       = aws_docdb_cluster.docdb.cluster_members
}

output "cluster_master_username" {
  description = "The DocumentDB master username"
  value       = aws_docdb_cluster.docdb.master_username
  sensitive   = true
}

output "cluster_master_password" {
  description = "The DocumentDB master password"
  value       = random_password.master.result
  sensitive   = true
}

output "cluster_master_password_ssm_arn" {
  description = "The DocumentDB master password ARN in Parameter Store"
  value       = aws_ssm_parameter.master_password.arn
}

output "cluster_hosted_zone_id" {
  description = "The Route53 Hosted Zone ID of the endpoint"
  value       = aws_docdb_cluster.docdb.hosted_zone_id
}

output "security_group_id" {
  description = "The security group ID of the DocumentDB cluster"
  value       = aws_security_group.docdb_security_group.id
}

output "subnet_group_name" {
  description = "The DocumentDB subnet group name"
  value       = aws_docdb_subnet_group.docdb.name
}

output "cluster_instances" {
  description = "Map of cluster instance attributes"
  value = {
    for idx, instance in aws_docdb_cluster_instance.docdb_instances :
    idx => {
      id                = instance.id
      arn               = instance.arn
      identifier        = instance.identifier
      endpoint          = instance.endpoint
      instance_class    = instance.instance_class
      availability_zone = instance.availability_zone
      promotion_tier    = instance.promotion_tier
    }
  }
}

output "connection_string" {
  description = "DocumentDB connection string (without credentials)"
  value       = "mongodb://${aws_docdb_cluster.docdb.endpoint}:${aws_docdb_cluster.docdb.port}/?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
}

output "connection_string_with_credentials" {
  description = "DocumentDB connection string with credentials"
  value       = "mongodb://${aws_docdb_cluster.docdb.master_username}:${random_password.master.result}@${aws_docdb_cluster.docdb.endpoint}:${aws_docdb_cluster.docdb.port}/?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
  sensitive   = true
}