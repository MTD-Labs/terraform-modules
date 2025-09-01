variable "name" {
  description = "Optional name for the Elasticsearch domain"
  type        = string
  default     = ""
}

variable "env" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the Elasticsearch domain"
  type        = string
}

variable "subnets" {
  description = "List of subnet IDs for Elasticsearch"
  type        = list(string)
}

variable "elasticsearch_version" {
  description = "Version of Elasticsearch to deploy"
  type        = string
  default     = "7.10"
}

variable "instance_type" {
  description = "Elasticsearch instance type"
  type        = string
  default     = "t3.small.elasticsearch"
}

variable "ebs_volume_size" {
  description = "Size of the EBS volume (in GB)"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
