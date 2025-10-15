variable "region" {
  description = "AWS region"
  type        = string
  default     = "me-south-1"
}

variable "env" {
  description = "Environment name"
  type        = string
  default     = null
}

variable "name" {
  description = "Name used across resources created"
  type        = string
  default     = ""
}

variable "tags" {
  description = "AWS Tags for resources"
  type        = map(string)
  default     = null
}

variable "domain_name" {
  description = "The domain name for the project"
  type        = string
  default     = "example.com"
}

variable "cdn_domain_name" {
  description = "The domain name for the cdn"
  type        = string
  default     = "cdn.example.com"
}

### VPC ###

variable "enable_nat_gateway" {
  type        = bool
  default     = true
  description = "Should be true if you want to provision NAT Gateways for each of your private networks"
}

variable "single_nat_gateway" {
  type        = bool
  default     = true
  description = "Should be true if you want to provision a single shared NAT Gateway across all of your private networks"
}

### EC2 Bastion ###

variable "bastion_enabled" {
  description = "Enable EC2 bastion instance"
  type        = bool
  default     = true
}

variable "bastion_ssh_authorized_keys_secret" {
  description = "Parameter store secret key with SSH authorized keys file content"
  type        = string
}

### ECS ###

variable "ecr_enabled" {
  description = "Enable ECR"
  type        = bool
  default     = false
}

variable "ecr_repositories" {
  description = "List of ECR repository names"
  type        = list(string)
  default     = []
}

variable "ecs_enabled" {
  description = "Enable ECS cluster"
  type        = bool
  default     = true
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "ecs_containers" {
  type = list(object({
    name                 = string
    image                = string
    command              = list(string)
    cpu                  = number
    memory               = number
    min_count            = number
    max_count            = number
    target_cpu_threshold = number
    target_mem_threshold = number
    path                 = optional(list(string), [])
    priority             = optional(number)
    port                 = number
    service_domain       = string
    envs                 = map(string)
    secrets              = map(string)
    health_check         = map(string)
    volumes = optional(list(object({
      name           = string
      container_path = string
      read_only      = optional(bool)
    })), [])
  }))
  default = [
    {
      name                 = "web-container"
      image                = "nginx:latest"
      command              = []
      cpu                  = 256
      memory               = 512
      min_count            = 1
      max_count            = 10
      target_cpu_threshold = 75
      target_mem_threshold = 80
      path                 = ["/"]
      priority             = 20
      port                 = 8080
      service_domain       = "domaon.example.com"
      envs                 = { ENV_VAR1 = "value1" }
      secrets              = { SECRET1 = "arn:aws:ssm:me-south-1:awsAccountID:parameter/secret1" }

      health_check = {
        matcher = "200"
        path    = "/"
      }
      volumes = [
        {
          name           = "web-container-efs-storage"
          container_path = "/opt/web-container-data"
          read_only      = false
        }
      ]
    },
    {
      name                 = "api-container"
      image                = "my-api:latest"
      command              = ["startup.sh"]
      cpu                  = 512
      memory               = 1024
      min_count            = 1
      max_count            = 10
      target_cpu_threshold = 75
      target_mem_threshold = 80
      path                 = ["/api"]
      priority             = 10
      port                 = 8081
      service_domain       = "domaon.example.com"
      envs                 = { ENV_VAR2 = "value1" }
      secrets              = { SECRET2 = "arn:aws:ssm:me-south-1:awsAccountID:parameter/secret2" }

      health_check = {
        matcher = "200"
        path    = "/"
      }
      volumes = [
        {
          name           = "api-container-efs-storage"
          container_path = "/opt/api-container-data"
          read_only      = false
        }
      ]
    }
    # Add more containers as needed
  ]
}

variable "alb_idle_timeout" {
  description = "Application Load Balancer Idle Timeout"
  type        = number
  default     = 60
}

### POSTGRES ###

variable "postgres_enabled" {
  description = "Enable Postgres RDS cluster"
  type        = bool
  default     = true
}

variable "postgres_rds_type" {
  description = "Simple RDS or Aurora"
  type        = string
  default     = "rds"
}

variable "postgres_engine_version" {
  description = "Engine version"
  type        = string
  default     = "15.5"
}

variable "postgres_family" {
  description = "Engine version"
  type        = string
  default     = "postgres15"
}

variable "postgres_instance_class" {
  description = "Instance class used"
  type        = string
  default     = "db.t3.medium"
}

variable "postgres_allocated_storage" {
  description = "Storage amount for DB"
  type        = number
  default     = 10
}

variable "postgres_max_allocated_storage" {
  description = "Maximum storage amount for DB (enables autoscaling), 0 is disabled"
  type        = number
  default     = 0
}

variable "postgres_rds_cluster_parameters" {
  description = "A map of parameters for RDS Aurora cluster, if applicable"
  type        = map(string)
  default     = {}
}

variable "postgres_rds_db_parameters" {
  description = "A map of parameters for RDS database instances, if applicable"
  type        = map(string)
  default = {
    "rds.force_ssl" = "0"
  }
}

variable "postgres_allow_vpc_cidr_block" {
  description = "Allow full VPC CIDR block for access"
  type        = bool
  default     = false
}

variable "postgres_allow_vpc_private_cidr_blocks" {
  description = "Allow VPC private CIDR blocks for access"
  type        = bool
  default     = true
}

variable "postgres_extra_allowed_cidr_blocks" {
  description = "extra allowed cidr blocks"
  type        = string
  default     = "10.0.0.0/8"
}

variable "backup_retention_period" {
  description = "The days to retain backups for"
  type        = number
  default     = 7
}

variable "postgres_preferred_maintenance_window" {
  description = "The weekly time range during which system maintenance can occur, in (UTC)"
  type        = string
  default     = "Sat:00:00-Sat:03:00"
}

variable "postgres_preferred_backup_window" {
  description = "The daily time range during which automated backups are created if automated backups are enabled using the `backup_retention_period` parameter. Time in UTC"
  type        = string
  default     = "03:00-06:00"
}

variable "postgres_master_username" {
  description = "master username"
  type        = string
  default     = "postgres"
}

variable "postgres_database_name" {
  description = "Database name to create initially"
  type        = string
  default     = "laravel"
}

variable "postgres_kms_ssm_key_arn" {
  type        = string
  description = "ARN of the AWS KMS key used for SSM encryption"
  default     = "alias/aws/ssm"
}

variable "postgres_database_user_map" {
  type        = map(string)
  description = "Map of databases and their users to create in RDS instance"
  default     = {}
}

### REDIS ###

variable "redis_enabled" {
  description = "Enable Redis cluster"
  type        = bool
  default     = true
}

variable "redis_cluster_size" {
  description = "Redis number of nodes in cluster"
  type        = number
  default     = 1
}

variable "redis_instance_type" {
  description = "Elastic cache instance type"
  type        = string
  default     = "cache.t2.micro"
}

variable "redis_engine_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.0.14"
}

variable "redis_family" {
  description = "Redis family"
  type        = string
  default     = "redis7.0"
}

variable "redis_cluster_mode_num_node_groups" {
  description = "Number of node groups (shards) for this Redis replication group. Changing this number will trigger an online resizing operation before other settings modifications"
  type        = number
  default     = 0
}

variable "redis_cluster_mode_enabled" {
  description = "Redis cluster mode enabled"
  type        = bool
  default     = false
}

variable "redis_automatic_failover_enabled" {
  description = "Redis automatic failover enabled"
  type        = bool
  default     = false
}

variable "redis_cluster_mode_replicas_per_node_group" {
  description = "Redis cluster mode replicas per node group"
  type        = number
  default     = 0
}

variable "redis_kms_ssm_key_arn" {
  type        = string
  description = "ARN of the AWS KMS key used for SSM encryption"
  default     = "alias/aws/ssm"
}

variable "redis_allow_vpc_cidr_block" {
  description = "Allow full VPC CIDR block for access"
  type        = bool
  default     = false
}

variable "redis_allow_vpc_private_cidr_blocks" {
  description = "Allow VPC private CIDR blocks for access"
  type        = bool
  default     = true
}

variable "redis_extra_allowed_cidr_blocks" {
  description = "extra allowed cidr blocks"
  type        = string
  default     = "10.0.0.0/8"
}

variable "redis_snapshot_retention_limit" {
  description = "The number of days for which ElastiCache will retain automatic cache cluster snapshots"
  type        = number
  default     = 7
}

variable "redis_snapshot_window" {
  description = "The daily time range (in UTC) during which ElastiCache will begin taking a daily snapshot"
  type        = string
  default     = "04:00-05:00"
}

### CDN ###

variable "cdn_enabled" {
  type    = bool
  default = false
}

variable "cdn_optimize_images" {
  type    = bool
  default = true
}

### S3 ###

variable "s3_bucket_list" {
  type = list(map(string))
  default = [
    {
      name       = "static"
      public     = true
      versioning = false
    }
    # Add more buckets as needed
  ]
}

### CLOUDTRAIL ###

variable "cloudtrail_enabled" {
  type    = bool
  default = false
}

variable "cloudtrail_log_retention_days" {
  type    = number
  default = 365
}

variable "lambda_image_url" {
  type    = string
  default = ""
}

variable "lambda_region" {
  type    = string
  default = null
}

variable "lambda_memory_size" {
  description = "Lambda Function Memory Size"
  type        = number
  default     = 128
}

variable "aws_email_service" {
  description = "Enable or disable AWS Email Service"
  type        = bool
  default     = false
}

variable "aws_email_domain" {
  description = "Domain for AWS Email Service"
  type        = string
  default     = "exmapl.com"
}

variable "mail_from_alias" {
  description = "Alias for Email from"
  type        = string
  default     = "mail.exmapl.com"
}

variable "elasticsearch_enabled" {
  description = "Enable Elasticsearch module"
  type        = bool
  default     = false
}

variable "elasticsearch_instance_type" {
  description = "Elasticsearch instance type"
  type        = string
  default     = "t3.small.elasticsearch"
}

variable "elasticsearch_ebs_volume_size" {
  description = "Elasticsearch EBS volume size"
  type        = number
  default     = 10
}

variable "elasticsearch_version" {
  description = "Elasticsearch version"
  type        = string
  default     = "7.10"
}

variable "loki_enabled" {
  type        = bool
  default     = false
  description = "Whether to enable Loki logging for ECS tasks"
}

variable "grafana_domain" {
  type        = string
  default     = "grafana.example.com"
  description = "Domain name for Grafana (required if loki_enabled is true)"
}

variable "loki_ec2_instance_type" {
  type        = string
  default     = "t3.medium"
  description = "Instance type for EC2 running Loki and Grafana"
}

variable "loki_ec2_key_name" {
  type        = string
  default     = ""
  description = "SSH key pair name for EC2 instance"
}

variable "grafana_admin_password" {
  type        = string
  default     = "StrongPassword"
  description = "The Secure Password for Grafana"
}

variable "lambda_bucket_name" {
  type    = string
  default = null
}

variable "ssm_secret_key" {
  type    = string
  default = null
}

variable "document_data_api_url" {
  type    = string
  default = null
}

variable "html_to_pdf_url" {
  type    = string
  default = null
}

variable "html_to_docx_url" {
  type    = string
  default = null
}

variable "alert_manager_url" {
  type        = string
  default     = "http://localhost:9093"
  description = "The Alert manager url"
}

variable "loki_instance_volume_size" {
  type        = number
  default     = 10
  description = "The Loki Ec2 Instance Disk Size"
}

variable "fluentbit_image" {
  type        = string
  default     = "grafana/fluent-bit-plugin-loki:1.5.0-amd64"
  description = "The Fluent Bit Docker Image"
}

variable "fluentbit_memoryreservation" {
  type        = number
  default     = 50
  description = "The Fluent Bit Memory Reservation"
}

variable "ami_owners" {
  description = "The list of owners used to select the AMI of used instances."
  type        = list(string)
  default     = ["099720109477"] # Canonical
}

variable "ubuntu_ami_name_pattern" {
  description = "The name pattern for Ubuntu AMI"
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"
}

variable "instance_arch" {
  description = "The arch of EC2 Instance"
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"
}
variable "lambda_edge_enabled" {
  type    = bool
  default = false
}

variable "efs_enabled" {
  description = "Enable EFS for shared storage"
  type        = bool
  default     = false
}

variable "efs_performance_mode" {
  description = "EFS performance mode"
  type        = string
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  description = "EFS throughput mode"
  type        = string
  default     = "bursting"
}

variable "efs_provisioned_throughput" {
  description = "Provisioned throughput in MiB/s (only valid when throughput_mode is provisioned)"
  type        = number
  default     = null
}

# Amazon MQ variables
variable "mq_enabled" {
  description = "Whether to create Amazon MQ resources"
  type        = bool
  default     = false
}

variable "mq_engine_type" {
  description = "Type of broker engine (ACTIVEMQ or RABBITMQ)"
  type        = string
  default     = "RABBITMQ"
}

variable "mq_engine_version" {
  description = "The version of the broker engine"
  type        = string
  default     = "3.13"
}

variable "mq_instance_type" {
  description = "The broker's instance type"
  type        = string
  default     = "mq.m7g.medium"
}

variable "mq_deployment_mode" {
  description = "The deployment mode of the broker (SINGLE_INSTANCE, ACTIVE_STANDBY_MULTI_AZ, CLUSTER_MULTI_AZ)"
  type        = string
  default     = "SINGLE_INSTANCE"
}

variable "mq_auto_minor_version_upgrade" {
  description = "Enables automatic upgrades to new minor versions for brokers"
  type        = bool
  default     = false
}

variable "mq_authentication_strategy" {
  description = "Authentication strategy for the broker (SIMPLE or LDAP)"
  type        = string
  default     = "SIMPLE"
}

variable "mq_admin_username" {
  description = "Admin username for the broker"
  type        = string
  default     = "admin"
}

variable "mq_users" {
  description = "Map of additional users and their configuration"
  type = map(object({
    groups         = list(string)
    console_access = optional(bool, false)
  }))
  default = {}
}

variable "mq_enable_general_logging" {
  description = "Enables general logging via CloudWatch"
  type        = bool
  default     = true
}

variable "mq_enable_audit_logging" {
  description = "Enables audit logging via CloudWatch"
  type        = bool
  default     = true
}

variable "mq_maintenance_day_of_week" {
  description = "The day of the week for maintenance window"
  type        = string
  default     = "SUNDAY"
}

variable "mq_maintenance_time_of_day" {
  description = "The time of day for maintenance window (format: HH:MM)"
  type        = string
  default     = "03:00"
}

variable "mq_maintenance_time_zone" {
  description = "The time zone for maintenance window"
  type        = string
  default     = "UTC"
}

variable "mq_kms_ssm_key_arn" {
  type        = string
  description = "ARN of the AWS KMS key used for SSM encryption"
  default     = "alias/aws/ssm"
}

variable "mq_kms_mq_key_arn" {
  type        = string
  description = "ARN of the AWS KMS key used for MQ encryption"
  default     = null
}

variable "mq_additional_security_group_ids" {
  description = "Additional security group IDs to allow access to MQ"
  type        = list(string)
  default     = []
}

variable "mq_allow_vpc_cidr_block" {
  description = "Allow full VPC CIDR block for access to MQ"
  type        = bool
  default     = false
}

variable "mq_allow_vpc_private_cidr_blocks" {
  description = "Allow VPC private CIDR blocks for access to MQ"
  type        = bool
  default     = true
}

variable "mq_extra_allowed_cidr_blocks" {
  description = "Extra allowed CIDR blocks for MQ access"
  type        = string
  default     = "10.0.0.0/8"
}

variable "mq_ecs_read_only_access" {
  description = "Whether to grant ECS tasks read-only access to MQ (instead of full access)"
  type        = bool
  default     = false
}


variable "webhook_path_prefix" {
  description = "WEbhook Path "
  type        = string
  default     = ""
}

variable "webhook_console_allowed_cidrs" {
  description = "Webhook Rabbit allow cidrs"
  type        = list(string)
  default     = []
}

variable "alchemy_source_ips" {
  description = "Static IPs allowed to call API Gateway (Alchemy egress IPs)."
  type        = list(string)
  default = [
    "54.236.136.17/32",
    "34.237.24.169/32",
    "87.241.157.116/32",
  ]
}

variable "rabbitmq_queue_name" {
  description = "Durable RabbitMQ queue name to publish webhook events to."
  type        = string
  default     = "alchemy.events"
}

variable "rabbitmq_queue_type" {
  description = "RabbitMQ queue type: 'quorum' (recommended for HA) or 'classic'."
  type        = string
  default     = "classic"

  validation {
    condition     = contains(["quorum", "classic", ""], var.rabbitmq_queue_type)
    error_message = "Queue type must be 'quorum', 'classic', or empty string."
  }
}

variable "webhook_enabled" {
  description = "Whether to create Amazon MQ resources"
  type        = bool
  default     = false
}

variable "enable_backup" {
  description = "Whether to create Amazon MQ resources"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Backup retention period in days."
  type        = number
  default     = 7
}

variable "backup_schedule" {
  description = "Backup schedule in cron format."
  type        = string
  default     = "cron(0 3 * * ? *)" # Daily at 3 AM UTC
}

variable "subject_alternative_names" {
  description = "Additional domain names to include in the certificate"
  type        = list(string)
  default     = []
}

variable "ecs_platform_version" {
  description = "ECS Platform Version"
  type        = string
  default     = "1.4.0"
}

variable "cloudflare_zone" {
  type        = string
  description = "Root zone in Cloudflare (e.g., trendex.my)"
  default     = "trendex.my"
}

variable "cloudflare_proxied" {
  type        = bool
  description = "Whether to enable Cloudflare proxy (orange cloud)"
  default     = false
}

variable "alb_security_group_id" { type = string }
