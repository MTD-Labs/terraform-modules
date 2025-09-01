locals {
  tags = merge({
    Env        = var.env
    tf-managed = true
    tf-module  = "aws/s3"
  }, var.tags)

  cors_rules_map = [
    {
      allowed_headers = []
      allowed_methods = ["GET"]
      allowed_origins = ["*"]
      expose_headers  = []
    },
    {
      allowed_headers = ["*"]
      allowed_methods = ["PUT", "HEAD"]
      allowed_origins = ["*"]
      expose_headers  = []
    }
  ]
}

module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "= 3.15.1"

  bucket                  = var.name
  acl                     = var.public ? "public-read" : "private"
  block_public_acls       = var.public ? false : true
  block_public_policy     = var.public ? false : true
  ignore_public_acls      = var.public ? false : true
  restrict_public_buckets = var.public ? false : true

  attach_policy = var.public ? true : false
  policy        = var.public ? data.aws_iam_policy_document.public.json : null

  cors_rule = var.public ? local.cors_rules_map : []

  versioning = {
    enabled = var.versioning
  }

  control_object_ownership = true
  object_ownership         = var.object_ownership

  tags = local.tags
}


data "aws_iam_policy_document" "public" {
  statement {
    sid = "PublicReadGetObject"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "arn:aws:s3:::${var.name}/*",
    ]
  }
}
