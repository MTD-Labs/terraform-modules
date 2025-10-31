locals {
  tags = merge({
    Env        = var.env
    tf-managed = true
    tf-module  = "aws/cloudtrail"
  }, var.tags)
}

module "aws_cloudtrail" {
  source  = "trussworks/cloudtrail/aws"
  version = "~> 5.3.0" # Update to latest version

  s3_bucket_name     = module.logs.aws_logs_bucket
  log_retention_days = var.log_retention_days
  tags               = local.tags
}

module "logs" {
  source  = "trussworks/logs/aws"
  version = "~> 18.0.0" # Update to v16+ to fix deprecation

  s3_bucket_name          = "audit-logs-${var.env}-${var.region}"
  s3_log_bucket_retention = var.log_retention_days
  default_allow           = false
  allow_cloudtrail        = true
  force_destroy           = true

  tags = local.tags
}