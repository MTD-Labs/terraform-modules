variable "region" {
  type    = string
  default = "me-south-1"
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

variable "route53_zone" {
  type        = string
  description = "Main VPC Route53 zone"
  default     = ""
}

variable "authorized_vpc_list" {
  type        = list(string)
  description = "VPC IDs of foreign accounts to associate main zone with"
  default     = []
}

variable "route53_additional_zone_list" {
  type        = list(string)
  description = "Additional private DNS zones to manage by Route53"
  default     = []
}

variable "associated_zone_list" {
  type        = list(string)
  description = "Zone IDs of foreign accounts to associate main VPC with"
  default     = []
}
