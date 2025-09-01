locals {
  public_bucket_list = [
    for bucket in var.s3_bucket_list : {
      name        = bucket.name
      domain_name = "${bucket.name}.s3.${var.region}.amazonaws.com"
      path        = bucket.path
    } if bucket.public
  ]

}

module "alb" {
  count  = var.cdn_enabled == true ? 1 : 0
  source = "../../aws/alb"

  providers = {
    aws.main      = aws.main
    aws.us_east_1 = aws.us_east_1
  }

  region = var.region
  env    = var.env
  name   = var.name
  tags   = var.tags

  cdn_domain_name = var.cdn_domain_name
  domain_name     = var.domain_name

  vpc_id      = module.vpc.vpc_id
  vpc_subnets = module.vpc.public_subnets

  idle_timeout = var.alb_idle_timeout

  #cdn_bucket_names = [module.s3[1].s3_bucket_bucket_regional_domain_name]
  cdn_enabled            = var.cdn_enabled
  cdn_buckets            = local.public_bucket_list
  cdn_optimize_images    = var.cdn_optimize_images
  lambda_image_url       = var.lambda_image_url
  lambda_region          = var.lambda_region
  lambda_memory_size     = var.lambda_memory_size
  lambda_private_subnets = module.vpc.private_subnets
  lambda_security_group  = [module.ec2[0].security_group_id]
  ecs_enabled            = var.ecs_enabled
}

module "vpc" {
  source = "../../aws/vpc"

  region = var.region
  env    = var.env

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

}

module "ecr" {
  count  = var.ecr_enabled == true ? 1 : 0
  source = "../../aws/ecr"

  providers = {
    aws.main      = aws.main
    aws.us_east_1 = aws.us_east_1
  }

  region = var.region
  env    = var.env
  name   = var.name
  tags   = var.tags

  ecr_repositories = var.ecr_repositories

}

module "ec2" {
  count  = var.bastion_enabled == true ? 1 : 0
  source = "../../aws/ec2-small"

  region = var.region
  env    = var.env
  name   = var.name
  tags   = var.tags

  vpc_id            = module.vpc.vpc_id
  private_subnet_id = module.vpc.private_subnets[0]
  public_subnet_id  = module.vpc.public_subnets[0]

  ssh_authorized_keys_secret = var.bastion_ssh_authorized_keys_secret
  allowed_tcp_ports          = var.allowed_tcp_ports
  enable_public_access       = true
  key_name                   = var.key_name
  ec2_root_volume_size       = var.ec2_root_volume_size
  ec2_root_volume_type       = var.ec2_root_volume_type
  additional_disk            = var.additional_disk
  additional_disk_size       = var.additional_disk_size
  additional_disk_type       = var.additional_disk_type
  private_key_path           = var.private_key_path
  ecr_user_id                = var.ecr_user_id
  instance_type              = var.instance_type
  domain_name                = var.domain_name
  ubuntu_ami_name_pattern    = var.ubuntu_ami_name_pattern
  instance_arch              = var.instance_arch
}

module "s3" {
  for_each = { for idx, bucket in var.s3_bucket_list : idx => bucket }
  source   = "../../aws/s3"

  region = var.region
  env    = var.env
  tags   = var.tags

  name       = each.value["name"]
  public     = each.value["public"]
  versioning = each.value["versioning"]
}

module "cloudtrail" {
  count  = var.cloudtrail_enabled == true ? 1 : 0
  source = "../../aws/cloudtrail"

  region = var.region
  env    = var.env
  name   = var.name
  tags   = var.tags

  log_retention_days = var.cloudtrail_log_retention_days
}
