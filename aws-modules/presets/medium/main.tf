locals {
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
      name                   = container.name
      image                  = container.image
      command                = container.command
      cpu                    = container.cpu
      memory                 = container.memory
      min_count              = container.min_count
      max_count              = container.max_count
      target_cpu_threshold   = container.target_cpu_threshold
      target_mem_threshold   = container.target_mem_threshold
      path                   = container.path
      priority               = container.priority
      port                   = container.port
      service_domain         = container.service_domain
      envs                   = merge(container.envs)
      secrets                = merge(container.secrets)
      health_check           = container.health_check
      container_health_check = container.container_health_check
      volumes                = container.volumes
    }
  ]
}

data "aws_caller_identity" "current" {}

module "vpc" {
  source = "../../aws/vpc"
  providers = {
    aws.main = aws.main
  }
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

  lambda_edge_enabled    = var.lambda_edge_enabled
  cdn_enabled            = var.cdn_enabled
  cdn_buckets            = local.public_bucket_list
  cdn_optimize_images    = var.cdn_optimize_images
  lambda_image_url       = var.lambda_image_url
  lambda_region          = var.lambda_region
  lambda_memory_size     = var.lambda_memory_size
  lambda_private_subnets = module.vpc.private_subnets
  lambda_security_group  = [module.alb.alb_aws_security_group_id]

  subject_alternative_names = var.subject_alternative_names

  cloudflare_proxied       = var.cloudflare_proxied
  cloudflare_zone          = var.cloudflare_zone
  create_cloudflare_record = var.create_cloudflare_record
  cloudflare_ttl           = var.cloudflare_ttl
}

module "ecr" {
  count  = var.ecr_enabled == true ? 1 : 0
  source = "../../aws/ecr"

  providers = {
    aws.main = aws.main
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
  vpc_cidr_block          = module.vpc.vpc_cidr_block
  cluster_name            = var.ecs_cluster_name
  containers              = local.final_ecs_containers

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
  loki_instance_arch    = var.loki_instance_arch

  cloudwatch_insights_enabled = var.ecs_cloudwatch_insights_enabled

  subscription_filter_enabled           = var.subscription_filter_enabled
  subscription_filter_slack_webhook_url = var.subscription_filter_slack_webhook_url
  subscription_filter_pattern           = var.subscription_filter_pattern

  ecs_scale_alarm_enabled           = var.ecs_scale_alarm_enabled
  ecs_scale_alarm_slack_webhook_url = var.ecs_scale_alarm_slack_webhook_url
  ecs_scale_alarm_ok_notifications  = var.ecs_scale_alarm_ok_notifications

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

  enable_rds_alarms               = var.enable_rds_alarms
  rds_cpu_threshold               = var.rds_cpu_threshold
  rds_free_memory_threshold_bytes = var.rds_free_memory_threshold_bytes
  rds_event_categories            = var.rds_event_categories

  enable_rds_storage_alarm            = var.enable_rds_storage_alarm
  rds_storage_usage_threshold_percent = var.rds_storage_usage_threshold_percent
}

resource "aws_iam_role_policy_attachment" "ecs_task_postgres_policy" {
  count      = var.postgres_enabled && var.ecs_enabled ? 1 : 0
  role       = module.ecs[0].ecs_task_exec_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSDataFullAccess"
}

resource "aws_iam_role_policy_attachment" "ecs_task_secretmanager_policy" {
  count      = var.postgres_enabled && var.ecs_enabled ? 1 : 0
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

  enable_redis_alarms                  = var.enable_redis_alarms
  redis_cpu_threshold                  = var.redis_cpu_threshold
  redis_node_max_memory_bytes          = var.redis_node_max_memory_bytes
  redis_memory_usage_threshold_percent = var.redis_memory_usage_threshold_percent

  depends_on = [module.vpc]
}

resource "aws_iam_role_policy_attachment" "ecs_task_redis_policy" {
  count      = var.redis_enabled && var.ecs_enabled ? 1 : 0
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
  allowed_tcp_ports          = ["22", "80", "443", "8000", "8020", "5001"]
  allowed_udp_ports          = ["51820"]
  grafana_enabled            = var.grafana_enabled
  grafana_domain             = var.grafana_domain
  ecr_user_id                = var.ecr_user_id
  instance_type              = var.bastion_instance_type
  depends_on                 = [module.secrets]
}

module "s3" {
  for_each = { for idx, bucket in var.s3_bucket_list : idx => bucket }
  source   = "../../aws/s3"
  providers = {
    aws.main = aws.main
  }
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
  providers = {
    aws.main = aws.main
  }

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

  aws_region   = var.region
  environment  = var.env
  project_name = var.name
  tags         = var.tags

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

module "eks" {
  source = "../../aws/eks"
  count  = var.eks_enabled == true ? 1 : 0
  providers = {
    aws.main = aws.main
  }

  region                  = var.region
  env                     = var.env
  tags                    = var.tags
  cluster_name            = var.eks_cluster_name
  vpc_id                  = module.vpc.vpc_id
  vpc_subnets             = module.vpc.private_subnets
  vpc_private_cidr_blocks = module.vpc.private_subnets_cidr_blocks
  kubernetes_version      = var.kubernetes_version
  instance_types          = var.eks_instance_types
  node_desired_size       = var.eks_node_desired_size
  node_min_size           = var.eks_node_min_size
  node_max_size           = var.eks_node_max_size
  service_ipv4_cidr       = var.eks_service_ipv4_cidr
  endpoint_private        = var.eks_endpoint_private
  endpoint_public         = var.eks_endpoint_public
  enabled_logs            = var.eks_enabled_logs

  # External Secrets Operator configuration
  install_external_secrets         = var.eks_install_external_secrets
  external_secrets_chart_version   = var.eks_external_secrets_chart_version
  external_secrets_allowed_secrets = var.eks_external_secrets_allowed_secrets
}


resource "null_resource" "wait_for_cluster" {
  count = var.eks_enabled ? 1 : 0

  provisioner "local-exec" {
    command = "echo Waiting for EKS cluster to be ready... && sleep 30"
  }

  depends_on = [module.eks[0]]
}

# Провайдер Kubernetes для EKS
provider "kubernetes" {
  alias = "eks"

  host                   = var.eks_enabled && length(module.eks) > 0 ? module.eks[0].cluster_endpoint : null
  cluster_ca_certificate = var.eks_enabled && length(module.eks) > 0 ? base64decode(module.eks[0].cluster_certificate_authority_data) : null

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = compact([
      "eks",
      "get-token",
      "--cluster-name",
      var.eks_enabled && length(module.eks) > 0 ? module.eks[0].cluster_name : "",
      "--output=json"
    ])
  }
}

provider "helm" {
  alias = "eks"

  kubernetes = {
    host                   = var.eks_enabled && length(module.eks) > 0 ? module.eks[0].cluster_endpoint : null
    cluster_ca_certificate = var.eks_enabled && length(module.eks) > 0 ? base64decode(module.eks[0].cluster_certificate_authority_data) : null

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = compact([
        "eks",
        "get-token",
        "--cluster-name",
        var.eks_enabled && length(module.eks) > 0 ? module.eks[0].cluster_name : "",
        "--output=json"
      ])
    }
  }
}

# External Secrets Operator installation
module "external_secrets" {
  count  = var.eks_enabled && var.eks_install_external_secrets ? 1 : 0
  source = "../../aws/external-secrets"

  providers = {
    aws.main      = aws.main
    aws.us_east_1 = aws.us_east_1
    kubernetes    = kubernetes.eks
    helm          = helm.eks
  }

  region                         = var.region
  install_external_secrets       = true
  external_secrets_chart_version = var.eks_external_secrets_chart_version
  external_secrets_role_arn      = module.eks[0].external_secrets_role_arn
  cluster_ready_dependency       = null_resource.wait_for_cluster[0]

  # SecretStore configuration
  create_secret_store    = var.eks_create_secret_store
  secret_store_name      = var.eks_secret_store_name
  secret_store_namespace = var.eks_secret_store_namespace

  # ClusterSecretStore configuration
  create_cluster_secret_store = var.eks_create_cluster_secret_store
  cluster_secret_store_name   = var.eks_cluster_secret_store_name

  depends_on = [
    null_resource.wait_for_cluster
  ]
}

module "ingress" {
  count  = var.eks_enabled ? 1 : 0
  source = "../../aws/ingress-controller"

  providers = {
    aws.main      = aws.main
    aws.us_east_1 = aws.us_east_1
    kubernetes    = kubernetes.eks
    helm          = helm.eks
  }

  env              = var.env
  cluster_name     = module.eks[0].cluster_name
  cluster_endpoint = module.eks[0].cluster_endpoint
  cluster_ca_cert  = module.eks[0].cluster_certificate_authority_data
  values_file_path = "${path.root}/helm-charts/ingress-controller"
  subnets          = module.vpc.private_subnets
  security_groups  = [module.eks[0].cluster_security_group_id]
  domain_name      = var.domain_name
  eks_enabled      = var.eks_enabled
}

module "grafana" {
  count  = var.eks_enabled ? 1 : 0
  source = "../../aws/monitoring/grafana"

  providers = {
    aws.main      = aws.main
    aws.us_east_1 = aws.us_east_1
    kubernetes    = kubernetes.eks
    helm          = helm.eks
  }

  env              = var.env
  cluster_name     = module.eks[0].cluster_name
  cluster_endpoint = module.eks[0].cluster_endpoint
  cluster_ca_cert  = module.eks[0].cluster_certificate_authority_data
  values_file_path = "${path.root}/helm-charts/grafana"
  subnets          = module.vpc.private_subnets
  host             = var.grafana_host
  eks_enabled      = var.eks_enabled
}

module "prometheus" {
  count  = var.eks_enabled ? 1 : 0
  source = "../../aws/monitoring/prometheus"

  providers = {
    aws.main      = aws.main
    aws.us_east_1 = aws.us_east_1
    kubernetes    = kubernetes.eks
    helm          = helm.eks
  }

  env              = var.env
  cluster_name     = module.eks[0].cluster_name
  cluster_endpoint = module.eks[0].cluster_endpoint
  cluster_ca_cert  = module.eks[0].cluster_certificate_authority_data
  values_file_path = "${path.root}/helm-charts/prometheus"
  subnets          = module.vpc.private_subnets
  eks_enabled      = var.eks_enabled
}

module "promtail" {
  count  = var.eks_enabled ? 1 : 0
  source = "../../aws/monitoring/promtail"

  providers = {
    aws.main      = aws.main
    aws.us_east_1 = aws.us_east_1
    kubernetes    = kubernetes.eks
    helm          = helm.eks
  }

  env              = var.env
  cluster_name     = module.eks[0].cluster_name
  cluster_endpoint = module.eks[0].cluster_endpoint
  cluster_ca_cert  = module.eks[0].cluster_certificate_authority_data
  values_file_path = "${path.root}/helm-charts/promtail"
  tenant_id        = var.tenant_id
  eks_enabled      = var.eks_enabled
}

module "loki" {
  count  = var.eks_enabled ? 1 : 0
  source = "../../aws/monitoring/loki"

  providers = {
    aws.main      = aws.main
    aws.us_east_1 = aws.us_east_1
    kubernetes    = kubernetes.eks
    helm          = helm.eks
  }

  env              = var.env
  cluster_name     = module.eks[0].cluster_name
  cluster_endpoint = module.eks[0].cluster_endpoint
  cluster_ca_cert  = module.eks[0].cluster_certificate_authority_data
  values_file_path = "${path.root}/helm-charts/loki"
  cluster_oidc_id  = module.eks[0].cluster_oidc_id
  loki_bucket_name = var.loki_bucket_name
  eks_enabled      = var.eks_enabled
  region           = var.region
}

module "metric-server" {
  count  = var.eks_enabled ? 1 : 0
  source = "../../aws/monitoring/metric-server"

  providers = {
    aws.main      = aws.main
    aws.us_east_1 = aws.us_east_1
    kubernetes    = kubernetes.eks
    helm          = helm.eks
  }

  env              = var.env
  cluster_name     = module.eks[0].cluster_name
  cluster_endpoint = module.eks[0].cluster_endpoint
  cluster_ca_cert  = module.eks[0].cluster_certificate_authority_data
  eks_enabled      = var.eks_enabled
}

module "secrets" {
  source = "../../aws/secrets"
  providers = {
    aws.main = aws.main
  }
  region           = var.region
  aws_secrets_list = var.aws_secrets_list
}

module "docdb" {
  count  = var.docdb_enabled ? 1 : 0
  source = "../../aws/docdb"

  providers = {
    aws.main = aws.main
  }

  env  = var.env
  name = var.name
  tags = var.tags

  vpc_id                  = module.vpc.vpc_id
  vpc_subnets             = module.vpc.private_subnets
  vpc_private_cidr_blocks = module.vpc.private_subnets_cidr_blocks

  engine_version                = var.docdb_engine_version
  family                        = var.docdb_family
  instance_class                = var.docdb_instance_class
  instance_count                = var.docdb_instance_count
  cluster_parameters            = var.docdb_cluster_parameters
  allow_vpc_cidr_block          = var.docdb_allow_vpc_cidr_block
  allow_vpc_private_cidr_blocks = var.docdb_allow_vpc_private_cidr_blocks
  extra_allowed_cidr_blocks     = var.docdb_extra_allowed_cidr_blocks
  backup_retention_period       = var.docdb_backup_retention_period
  preferred_maintenance_window  = var.docdb_preferred_maintenance_window
  preferred_backup_window       = var.docdb_preferred_backup_window
  master_username               = var.docdb_master_username

  kms_ssm_key_arn           = var.docdb_kms_ssm_key_arn
  kms_key_arn               = var.docdb_kms_key_arn
  bastion_security_group_id = var.bastion_enabled ? module.ec2[0].security_group_id : ""

  apply_immediately               = var.docdb_apply_immediately
  skip_final_snapshot             = var.docdb_skip_final_snapshot
  enabled_cloudwatch_logs_exports = var.docdb_enabled_cloudwatch_logs_exports
  deletion_protection             = var.docdb_deletion_protection
  auto_minor_version_upgrade      = var.docdb_auto_minor_version_upgrade

  enable_docdb_alarms                 = var.enable_docdb_alarms
  docdb_cpu_threshold                 = var.docdb_cpu_threshold
  docdb_free_memory_threshold_bytes   = var.docdb_free_memory_threshold_bytes
  docdb_connection_zero_alarm_periods = var.docdb_connection_zero_alarm_periods
}

# IAM policy for ECS to access DocumentDB (if ECS is enabled)
resource "aws_iam_policy" "ecs_docdb_access" {
  count = var.docdb_enabled && var.ecs_enabled ? 1 : 0

  name        = "${var.env}-${var.name}-docdb-access"
  description = "Access to DocumentDB for ECS tasks"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.env}-docdb-${var.name}-master-password"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "docdb:DescribeDBClusters",
          "docdb:DescribeDBInstances",
          "docdb:ListTagsForResource"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_docdb_policy" {
  count      = var.docdb_enabled && var.ecs_enabled ? 1 : 0
  role       = module.ecs[0].ecs_task_exec_role_name
  policy_arn = aws_iam_policy.ecs_docdb_access[0].arn
}

module "mq" {
  count  = var.mq_enabled ? 1 : 0
  source = "../../aws/mq-broker"

  providers = {
    aws.main = aws.main
  }

  env  = var.env
  name = var.name
  tags = var.tags

  vpc_id                  = module.vpc.vpc_id
  vpc_subnets             = [module.vpc.private_subnets[0]]
  vpc_cidr_block          = module.vpc.vpc_cidr_block
  vpc_private_cidr_blocks = module.vpc.private_subnets_cidr_blocks

  engine_type                = var.mq_engine_type
  engine_version             = var.mq_engine_version
  instance_type              = var.mq_instance_type
  deployment_mode            = var.mq_deployment_mode
  auto_minor_version_upgrade = var.mq_auto_minor_version_upgrade
  authentication_strategy    = var.mq_authentication_strategy
  admin_username             = var.mq_admin_username
  # users                      = var.mq_users

  enable_general_logging = var.mq_enable_general_logging
  enable_audit_logging   = var.mq_enable_audit_logging

  maintenance_day_of_week = var.mq_maintenance_day_of_week
  maintenance_time_of_day = var.mq_maintenance_time_of_day
  maintenance_time_zone   = var.mq_maintenance_time_zone

  kms_ssm_key_arn = var.mq_kms_ssm_key_arn
  kms_mq_key_arn  = var.mq_kms_mq_key_arn

  bastion_security_group_id     = var.bastion_enabled ? module.ec2[0].security_group_id : ""
  additional_security_group_ids = var.mq_additional_security_group_ids
  allow_vpc_cidr_block          = var.mq_allow_vpc_cidr_block
  allow_vpc_private_cidr_blocks = var.mq_allow_vpc_private_cidr_blocks
  extra_allowed_cidr_blocks     = var.mq_extra_allowed_cidr_blocks

  enable_mq_alarms                = var.enable_mq_alarms
  enable_mq_disk_alarm            = var.enable_mq_disk_alarm
  mq_disk_total_gib               = var.mq_disk_total_gib
  mq_disk_usage_threshold_percent = var.mq_disk_usage_threshold_percent
}

# IAM policy for ECS to access MQ (if ECS is enabled)
resource "aws_iam_role_policy_attachment" "ecs_task_mq_policy" {
  count      = var.mq_enabled && var.ecs_enabled ? 1 : 0
  role       = module.ecs[0].ecs_task_exec_role_name
  policy_arn = "arn:aws:iam::aws:policy/AmazonMQFullAccess"
}

# Optional: IAM policy for specific MQ access if needed
resource "aws_iam_policy" "mq_read_only" {
  count = var.mq_enabled && var.mq_ecs_read_only_access ? 1 : 0

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

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_task_mq_read_only" {
  count = var.mq_enabled && var.ecs_enabled && var.mq_ecs_read_only_access ? 1 : 0

  role       = module.ecs[0].ecs_task_exec_role_name
  policy_arn = aws_iam_policy.mq_read_only[0].arn
}

module "eks_apps" {
  for_each = var.eks_enabled ? toset(var.eks_apps) : []

  source = "../../aws/helm-apps"

  providers = {
    aws.main      = aws.main
    aws.us_east_1 = aws.us_east_1
    kubernetes    = kubernetes.eks
    helm          = helm.eks
  }

  env              = var.env
  namespace        = var.eks_namespace
  region           = var.region
  app_name         = each.value
  cluster_name     = module.eks[0].cluster_name
  cluster_endpoint = module.eks[0].cluster_endpoint
  cluster_ca_cert  = module.eks[0].cluster_certificate_authority_data
  values_file_path = "${path.root}/helm-charts/apps/${each.value}"
  eks_enabled      = var.eks_enabled
  chart_name       = var.chart_name
  chart_version    = var.chart_version
  depends_on       = [module.eks, module.external_secrets]
}
