locals {
  # ---------- Cache (Redis) ----------
  # cache_envs = {
  #   CACHE_DRIVER     = "redis"
  #   SESSION_DRIVER   = "redis"
  #   REDIS_HOST       = format("%s://%s", "tls", module.redis[0].endpoint)
  #   QUEUE_CONNECTION = "redis"
  # }
  # cache_secrets = {
  #   REDIS_PASSWORD = module.redis[0].auth_token_ssm_arn
  # }

  # ---------- Database (Postgres) ----------
  # db_envs = {
  #   DB_CONNECTION = "pgsql"
  #   DB_HOST       = var.postgres_rds_type == "rds" ? module.postgres[0].rds_instance_address[0] : module.postgres[0].cluster_endpoint[0]
  #   DB_PORT       = "5432"
  #   DB_DATABASE   = var.postgres_database_name
  #   DB_USERNAME   = var.postgres_master_username
  # }
  # db_secrets = {
  #   DB_PASSWORD = module.postgres[0].rds_instance_master_password_ssm_arn
  # }

  # # ---------- Amazon MQ (conditional) ----------
  # mq_envs = var.mq_enabled ? {
  #   BROKER_URL      = module.mq[0].broker_endpoints.stomp_ssl
  #   BROKER_USERNAME = var.mq_admin_username
  #   BROKER_TYPE     = "activemq"
  # } : {}

  # mq_secrets = var.mq_enabled ? {
  #   BROKER_PASSWORD = module.mq[0].admin_password_ssm_arn
  # } : {}

  # ---------- Public buckets for CDN ----------
  public_bucket_list = [
    for bucket in var.s3_bucket_list : {
      name        = bucket.name
      domain_name = "${bucket.name}.s3.${var.region}.amazonaws.com"
      path        = bucket.path
    } if bucket.public
  ]

  # ---------- Final ECS containers (single source of truth) ----------
  final_ecs_containers = [
    for container in var.ecs_containers : {
      name                 = container.name
      image                = container.image
      command              = container.command
      cpu                  = container.cpu
      memory               = container.memory
      min_count            = container.min_count
      max_count            = container.max_count
      target_cpu_threshold = container.target_cpu_threshold
      target_mem_threshold = container.target_mem_threshold
      path                 = container.path
      priority             = container.priority
      port                 = container.port
      service_domain       = container.service_domain
      envs                 = merge(container.envs)
      secrets              = merge(container.secrets)
      health_check         = container.health_check
      volumes              = container.volumes
    }
  ]
}


module "vpc" {
  source = "../../aws/vpc"

  region = var.region
  env    = var.env

  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway

  ecs_enabled      = var.ecs_enabled
  postgres_enabled = var.postgres_enabled


}

module "alb" {
  source = "../../aws/alb"

  providers = {
    aws.main      = aws.main
    aws.us_east_1 = aws.us_east_1
  }

  region = var.region
  env    = var.env
  name   = var.name
  tags   = var.tags

  domain_name     = var.domain_name
  cdn_domain_name = var.cdn_domain_name
  ecs_enabled     = var.ecs_enabled
  vpc_id          = module.vpc.vpc_id
  vpc_subnets     = module.vpc.public_subnets

  idle_timeout = var.alb_idle_timeout

  #cdn_bucket_names = [module.s3[1].s3_bucket_bucket_regional_domain_name]
  lambda_edge_enabled = var.lambda_edge_enabled
  ############# If using docker image for lambda, set lambda_edge_enabled to `false`:
  cdn_enabled            = var.cdn_enabled
  cdn_buckets            = local.public_bucket_list
  cdn_optimize_images    = var.cdn_optimize_images
  lambda_image_url       = var.lambda_image_url
  lambda_region          = var.lambda_region
  lambda_memory_size     = var.lambda_memory_size
  lambda_private_subnets = module.vpc.private_subnets
  lambda_security_group  = [module.alb.alb_aws_security_group_id]

  subject_alternative_names = var.subject_alternative_names

  cloudflare_proxied         = var.cloudflare_proxied
  cloudflare_zone            = var.cloudflare_zone
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

module "ecs" {
  count  = var.ecs_enabled == true ? 1 : 0
  source = "../../aws/ecs"

  providers = {
    aws.main      = aws.main
    aws.us_east_1 = aws.us_east_1
  }

  region = var.region
  env    = var.env
  name   = var.name
  tags   = var.tags

  vpc_id                  = module.vpc.vpc_id
  vpc_subnets             = module.vpc.private_subnets
  alb_security_group      = module.alb.alb_aws_security_group_id
  alb_listener_arn        = module.alb.alb_listener_https_arn
  vpc_private_cidr_blocks = module.vpc.private_subnets_cidr_blocks

  cluster_name = var.ecs_cluster_name
  containers   = local.final_ecs_containers

  loki_enabled           = var.loki_enabled
  grafana_domain         = var.grafana_domain
  loki_ec2_instance_type = var.loki_ec2_instance_type
  loki_ec2_key_name      = var.loki_ec2_key_name
  grafana_admin_password = var.grafana_admin_password

  efs_enabled          = var.efs_enabled
  efs_performance_mode = var.efs_performance_mode
  efs_throughput_mode  = var.efs_throughput_mode

  ecs_platform_version = var.ecs_platform_version

  alb_security_group_id = module.alb.alb_aws_security_group_id

}

module "postgres" {
  bastion_security_group_id = module.ec2[0].security_group_id
  count                     = var.postgres_enabled == true ? 1 : 0
  source                    = "../../aws/postgres"

  region = var.region
  env    = var.env
  name   = var.name
  tags   = var.tags

  vpc_id                  = module.vpc.vpc_id
  vpc_private_cidr_blocks = module.vpc.private_subnets_cidr_blocks
  vpc_subnets             = module.vpc.database_subnets
  vpc_subnet_group_name   = module.vpc.database_subnet_group_name

  rds_type                      = var.postgres_rds_type
  engine_version                = var.postgres_engine_version
  family                        = var.postgres_family
  instance_class                = var.postgres_instance_class
  allocated_storage             = var.postgres_allocated_storage
  max_allocated_storage         = var.postgres_max_allocated_storage
  rds_cluster_parameters        = var.postgres_rds_cluster_parameters
  rds_db_parameters             = var.postgres_rds_db_parameters
  allow_vpc_cidr_block          = var.postgres_allow_vpc_cidr_block
  allow_vpc_private_cidr_blocks = var.postgres_allow_vpc_private_cidr_blocks
  extra_allowed_cidr_blocks     = var.postgres_extra_allowed_cidr_blocks
  backup_retention_period       = var.backup_retention_period
  preferred_maintenance_window  = var.postgres_preferred_maintenance_window
  preferred_backup_window       = var.postgres_preferred_backup_window
  master_username               = var.postgres_master_username
  database_name                 = var.postgres_database_name
  database_user_map             = var.postgres_database_user_map
}

resource "aws_iam_role_policy_attachment" "ecs_task_postgres_policy" {
  count      = var.postgres_enabled == true ? 1 : 0
  role       = module.ecs[0].ecs_task_exec_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSDataFullAccess"
}

resource "aws_iam_role_policy_attachment" "ecs_task_secretmanager_policy" {
  count      = var.postgres_enabled == true ? 1 : 0
  role       = module.ecs[0].ecs_task_exec_role_name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

module "redis" {
  count  = var.redis_enabled == true ? 1 : 0
  source = "../../aws/redis"

  region = var.region
  env    = var.env
  name   = var.name
  tags   = var.tags

  vpc_id                  = module.vpc.vpc_id
  vpc_subnets             = module.vpc.private_subnets
  vpc_private_cidr_blocks = module.vpc.private_subnets_cidr_blocks

  cluster_size                         = var.redis_cluster_size
  instance_type                        = var.redis_instance_type
  engine_version                       = var.redis_engine_version
  family                               = var.redis_family
  cluster_mode_num_node_groups         = var.redis_cluster_mode_num_node_groups
  cluster_mode_enabled                 = var.redis_cluster_mode_enabled
  automatic_failover_enabled           = var.redis_automatic_failover_enabled
  cluster_mode_replicas_per_node_group = var.redis_cluster_mode_replicas_per_node_group
  snapshot_retention_limit             = var.redis_snapshot_retention_limit
  snapshot_window                      = var.redis_snapshot_window
  kms_ssm_key_arn                      = var.redis_kms_ssm_key_arn
  allow_vpc_cidr_block                 = var.redis_allow_vpc_cidr_block
  allow_vpc_private_cidr_blocks        = var.redis_allow_vpc_private_cidr_blocks
  extra_allowed_cidr_blocks            = var.redis_extra_allowed_cidr_blocks

}

resource "aws_iam_role_policy_attachment" "ecs_task_redis_policy" {
  count      = var.redis_enabled == true ? 1 : 0
  role       = module.ecs[0].ecs_task_exec_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElastiCacheFullAccess"
}

module "ec2" {
  count  = var.bastion_enabled == true ? 1 : 0
  source = "../../aws/ec2"

  region = var.region
  env    = var.env
  name   = var.name
  tags   = var.tags

  vpc_id            = module.vpc.vpc_id
  private_subnet_id = module.vpc.private_subnets[0]
  public_subnet_id  = module.vpc.public_subnets[0]

  ssh_authorized_keys_secret = var.bastion_ssh_authorized_keys_secret
  allowed_tcp_ports          = ["22"]

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

module "ses" {
  count            = var.aws_email_service == true ? 1 : 0
  source           = "../../aws/ses"
  aws_email_domain = var.domain_name
  mail_from_alias  = var.mail_from_alias
}

module "elasticsearch" {
  count  = var.elasticsearch_enabled == true ? 1 : 0
  source = "../../aws/elasticsearch"

  env                   = var.env
  name                  = var.name
  vpc_id                = module.vpc.vpc_id
  subnets               = module.vpc.private_subnets
  elasticsearch_version = var.elasticsearch_version
  instance_type         = var.elasticsearch_instance_type
  ebs_volume_size       = var.elasticsearch_ebs_volume_size
  tags                  = var.tags
}

module "webhook" {
  count  = var.webhook_enabled == true ? 1 : 0
  source = "../../aws/webhook"

  providers = {
    aws.main      = aws.main
    aws.us_east_1 = aws.us_east_1
  }

  aws_region                 = var.region
  environment                = var.env
  project_name               = var.name
  tags                       = var.tags

  webhook_path_prefix    = var.webhook_path_prefix
  api_stage_name         = var.env
  vpc_id                 = module.vpc.vpc_id
  vpc_private_subnet_ids = module.vpc.private_subnets
  console_allowed_cidrs  = var.webhook_console_allowed_cidrs

  mq_engine_version  = var.mq_engine_version
  mq_instance_type   = var.mq_instance_type
  mq_deployment_mode = var.mq_deployment_mode
  mq_admin_username  = var.mq_admin_username

  alchemy_source_ips  = var.alchemy_source_ips
  rabbitmq_queue_name = var.rabbitmq_queue_name
  rabbitmq_queue_type = var.rabbitmq_queue_type

  enable_backup         = var.enable_backup
  backup_retention_days = var.backup_retention_days
  backup_schedule       = var.backup_schedule
}

module "mq" {
  count  = var.mq_enabled == true ? 1 : 0
  source = "../../aws/mq-broker"

  region = var.region
  env    = var.env
  name   = var.name
  tags   = var.tags

  vpc_id                  = module.vpc.vpc_id
  vpc_subnets             = module.vpc.private_subnets
  vpc_cidr_block          = module.vpc.vpc_cidr_block
  vpc_private_cidr_blocks = module.vpc.private_subnets_cidr_blocks

  engine_type                = var.mq_engine_type
  engine_version             = var.mq_engine_version
  instance_type              = var.mq_instance_type
  deployment_mode            = var.mq_deployment_mode
  auto_minor_version_upgrade = var.mq_auto_minor_version_upgrade
  authentication_strategy    = var.mq_authentication_strategy
  admin_username             = var.mq_admin_username
  users                      = var.mq_users

  enable_general_logging = var.mq_enable_general_logging
  enable_audit_logging   = var.mq_enable_audit_logging

  maintenance_day_of_week = var.mq_maintenance_day_of_week
  maintenance_time_of_day = var.mq_maintenance_time_of_day
  maintenance_time_zone   = var.mq_maintenance_time_zone

  kms_ssm_key_arn = var.mq_kms_ssm_key_arn
  kms_mq_key_arn  = var.mq_kms_mq_key_arn

  bastion_security_group_id     = module.ec2[0].security_group_id
  additional_security_group_ids = var.mq_additional_security_group_ids
  allow_vpc_cidr_block          = var.mq_allow_vpc_cidr_block
  allow_vpc_private_cidr_blocks = var.mq_allow_vpc_private_cidr_blocks
  extra_allowed_cidr_blocks     = var.mq_extra_allowed_cidr_blocks
}



resource "aws_iam_role_policy_attachment" "ecs_task_mq_policy" {
  count      = var.mq_enabled == true ? 1 : 0
  role       = module.ecs[0].ecs_task_exec_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonMQFullAccess"
}

# Optional: IAM policy for specific MQ access if needed
resource "aws_iam_policy" "mq_read_only" {
  count = var.mq_enabled == true && var.mq_ecs_read_only_access ? 1 : 0

  name        = "${var.env}-${var.name}-mq-read-only"
  description = "Read-only access to Amazon MQ for ${var.env} environment"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "mq:DescribeBroker",
          "mq:ListBrokers",
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_mq_read_only" {
  count = var.mq_enabled == true && var.mq_ecs_read_only_access ? 1 : 0

  role       = module.ecs[0].ecs_task_exec_role_name
  policy_arn = aws_iam_policy.mq_read_only[0].arn
}
