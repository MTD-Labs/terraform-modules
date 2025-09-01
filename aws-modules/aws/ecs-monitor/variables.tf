variable "region" {
  type    = string
  default = "us-west-1"
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

variable "vpc_private_cidr_blocks" {
  type = list(string)
}

variable "alb_security_group" {
  type = string
}

variable "alb_listener_arn" {
  type = string
}

variable "ecs_cluster_id" {
  type = string
}

variable "ecs_cloudwatch_group_name" {
  type = string
}

variable "ecs_service_discovery_namespace_id" {
  type = string
}

variable "ecs_task_role_arn" {
  type = string
}

variable "ecs_exec_role_arn" {
  type = string
}

variable "ecs_security_group_ids" {
  type = list(string)
}

variable "prometheus_image" {
  type    = string
  default = "quay.io/prometheus/prometheus:v2.45.3"
}

variable "prometheus_config_reloader_image" {
  type    = string
  default = "public.ecr.aws/awsvijisarathy/prometheus-sdconfig-reloader:1.0"
}

variable "grafana_image" {
  type    = string
  default = "grafana/grafana:10.3.1"
}