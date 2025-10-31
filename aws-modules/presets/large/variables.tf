variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
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