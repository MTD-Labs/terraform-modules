output "loki_bucket_name" {
  description = "Name of the S3 bucket used by Loki"
  value       = aws_s3_bucket.loki_bucket[0].bucket
}
