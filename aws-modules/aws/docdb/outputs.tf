# Cluster identifiers
output "cluster_arn" {
  description = "ARN of the DocumentDB cluster"
  value       = aws_docdb_cluster.this.arn
}

output "cluster_id" {
  description = "ID of the DocumentDB cluster"
  value       = aws_docdb_cluster.this.id
}

# Endpoints / port
output "cluster_endpoint" {
  description = "Writer endpoint for the cluster"
  value       = aws_docdb_cluster.this.endpoint
}

output "cluster_reader_endpoint" {
  description = "Reader endpoint for the cluster"
  value       = aws_docdb_cluster.this.reader_endpoint
}

output "cluster_port" {
  description = "Port the cluster listens on"
  value       = aws_docdb_cluster.this.port
}

# Instances
output "instance_endpoints" {
  description = "Endpoints for each cluster instance"
  value       = [for i in aws_docdb_cluster_instance.this : i.endpoint]
}

# Auth (sensitive)
output "master_username" {
  description = "Master username"
  value       = var.master_username
  sensitive   = true
}

output "master_password" {
  description = "Master password"
  value       = random_password.master.result
  sensitive   = true
}

output "master_password_ssm_arn" {
  description = "SSM Parameter ARN storing the master password"
  value       = aws_ssm_parameter.master_password.arn
}

# Security Group
output "security_group_id" {
  description = "Security Group ID used by the cluster"
  value       = aws_security_group.docdb_sg.id
}

# Convenience: ready-to-use Mongo connection URIs (TLS required by DocDB)
output "writer_mongodb_uri" {
  description = "MongoDB URI for writer endpoint (TLS, replicaSet, retryWrites=false)"
  value       = "mongodb://${var.master_username}:${random_password.master.result}@${aws_docdb_cluster.this.endpoint}:${aws_docdb_cluster.this.port}/${var.default_database}?replicaSet=rs0&readPreference=primary&retryWrites=false&tls=true"
  sensitive   = true
}

output "reader_mongodb_uri" {
  description = "MongoDB URI for reader endpoint (TLS, prefer readers)"
  value       = "mongodb://${var.master_username}:${random_password.master.result}@${aws_docdb_cluster.this.reader_endpoint}:${aws_docdb_cluster.this.port}/${var.default_database}?replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false&tls=true"
  sensitive   = true
}
