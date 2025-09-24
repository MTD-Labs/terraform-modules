variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
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
  default     = false
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
  default     = false
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
    path                 = string
    priority             = number
    port                 = number
    envs                 = map(string)
    secrets              = map(string)
    health_check         = map(string)
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
      path                 = "/"
      priority             = 20
      port                 = 8080
      envs                 = { ENV_VAR1 = "value1" }
      secrets              = { SECRET1 = "arn:aws:ssm:us-east-1:awsAccountID:parameter/secret1" }

      health_check = {
        matcher = "200"
        path    = "/"
      }
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
      path                 = "/api"
      priority             = 10
      port                 = 8081
      envs                 = { ENV_VAR2 = "value1" }
      secrets              = { SECRET2 = "arn:aws:ssm:us-east-1:awsAccountID:parameter/secret2" }

      health_check = {
        matcher = "200"
        path    = "/"
      }
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
  default     = false
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
  default     = false
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

variable "redis_snapshot_retention_limit" {
  type        = number
  description = "The number of days for which ElastiCache will retain automatic cache cluster snapshots before deleting them."
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

### CDN ###

variable "cdn_enabled" {
  type    = bool
  default = true
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

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "allowed_tcp_ports" {
  type    = list(string)
  default = [""]
}
variable "ecr_user_id" {
  description = "Account ID for docker login for ec2 instance"
  type        = string
  default     = null
}

variable "private_key_path" {
  description = "Key Pair Path terraform connect to instance"
  type        = string
  default     = null
}

variable "additional_disk_type" {
  description = "Attached Disk Type"
  type        = string
  default     = "gp2"
}

variable "additional_disk_size" {
  description = "Attached Disk Size"
  type        = number
  default     = 10
}

variable "additional_disk" {
  description = "Attach Additional Disk To Instance"
  type        = bool
  default     = false
}

variable "ec2_root_volume_type" {
  description = "Disk Type"
  type        = string
  default     = "gp2"
}

variable "ec2_root_volume_size" {
  description = "Root Volume Disk Size"
  type        = number
  default     = 10
}

variable "key_name" {
  description = "EC2 Key Pair Name"
  type        = string
  default     = null
}

variable "enable_public_access" {
  description = "Attach Real IP to Instance"
  type        = bool
  default     = true
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

variable "services_list" {
  type    = list(string)
  default = ["service1", "service2"]
}

variable "cloudflare_api_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API token with Zone.DNS:Edit on the zone"
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
