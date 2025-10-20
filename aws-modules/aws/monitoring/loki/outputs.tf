output "loki_iam_role_arn" {
  description = "IAM Role ARN for the Loki ServiceAccount"
  value       = aws_iam_role.loki_role.arn
}

output "loki_bucket_name" {
  description = "Name of the S3 bucket used by Loki"
  value       = aws_s3_bucket.loki_bucket.bucket
}
