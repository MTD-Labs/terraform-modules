output "cluster_name" {
  value       = aws_eks_cluster.this.name
  description = "EKS cluster name"
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.this.endpoint
  description = "EKS API server endpoint"
}

output "cluster_certificate_authority_data" {
  value       = aws_eks_cluster.this.certificate_authority[0].data
  description = "Base64 encoded certificate data required to communicate with the cluster"
}

output "node_group_name" {
  value       = aws_eks_node_group.default.node_group_name
  description = "EKS managed node group name"
}

output "cluster_security_group_id" {
  value       = aws_security_group.eks_cluster.id
  description = "Security Group ID of the EKS control plane"
}

output "worker_iam_role_arn" {
  value       = aws_iam_role.eks_node.arn
  description = "IAM Role ARN of worker nodes"
}
