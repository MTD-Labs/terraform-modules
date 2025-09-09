locals {
  tags = merge({
    Env        = var.env
    tf-managed = true
    tf-module  = "aws/cloudtrail"
  }, var.tags)
}

module "aws_cloudtrail" {
  source  = "trussworks/cloudtrail/aws"
  # you can keep your current v4.4.0; or bump safely within v4
  version = "~> 4.0"

  s3_bucket_name     = module.logs.aws_logs_bucket
  log_retention_days = var.log_retention_days

  tags = local.tags
}

module "logs" {
  source  = "trussworks/logs/aws"
  # bump to v15 to remove deprecations
  version = ">= 15.0.0, < 16.0.0"

  s3_bucket_name          = "audit-logs-${var.env}-${var.region}"
  s3_log_bucket_retention = var.log_retention_days

  # keep your policy intent the same
  default_allow    = false
  allow_cloudtrail = true

  force_destroy = true
}
