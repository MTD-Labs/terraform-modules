variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "env" {
  type = string
}

variable "name" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = null
}

variable "vpc_id" {
  type = string
}

variable "vpc_subnets" {
  type = list(string)
}

variable "alb_security_group" {
  type = string
}

variable "alb_listener_arn" {
  type = string
}

variable "custom_origin_host_header" {
  default = "FFG"
  type    = string
}

variable "cluster_name" {
  type = string
}

variable "vpc_private_cidr_blocks" {
  type = list(string)
}

variable "containers" {
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
    path                 = list(string)
    port                 = number
    service_domain       = string
    priority             = number
    envs                 = map(string)
    secrets              = map(string)
    health_check         = map(string)
    container_health_check = optional(object({
      command      = optional(string)
      interval     = optional(number)
      retries      = optional(number)
      timeout      = optional(number)
      start_period = optional(number)
    }))
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
      secrets              = { SECRET1 = "arn:aws:ssm:ap-south-1:awsAccountID:parameter/secret1" }

      health_check = {
        matcher = "200"
        path    = "/"
      }
      container_health_check = {
        command      = "curl -f http://localhost:8080/ || exit 1"
        interval     = 30
        retries      = 3
        timeout      = 5
        start_period = 60
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
      envs                 = { ENV_VAR1 = "value1" }
      secrets              = { SECRET1 = "arn:aws:ssm:ap-south-1:awsAccountID:parameter/secret1" }

      health_check = {
        matcher = "200"
        path    = "/"
      }
      container_health_check = {
        command      = "curl -f http://localhost:8081/api/health || exit 1"
        interval     = 30
        retries      = 3
        timeout      = 5
        start_period = 90
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

variable "ubuntu_ami_name_pattern" {
  description = "The name pattern for Ubuntu AMI"
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"
}

variable "loki_instance_arch" {
  description = "The arch of EC2 Instance"
  type        = string
  default     = "arm64"
}

variable "ami_owners" {
  description = "The list of owners used to select the AMI of used instances."
  type        = list(string)
  default     = ["099720109477"] # Canonical
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
variable "ecs_platform_version" {
  description = "ECS Platform Version"
  type        = string
  default     = "1.4.0"
}

variable "alb_security_group_id" {
  type        = string
  description = "ALB SG ID to Allow Loki"
  default     = ""
}

variable "ubuntu_ami_name_pattern_loki" {
  description = "AMI name pattern for Ubuntu 24.04"
  type        = string
  default     = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
}

variable "cloudwatch_insights_enabled" {
  type    = bool
  default = true
}

variable "vpc_cidr_block" {
  description = "Full VPC CIDR Block"
  type        = string
}

