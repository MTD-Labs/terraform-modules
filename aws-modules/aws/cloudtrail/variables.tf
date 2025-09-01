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

variable "log_retention_days" {
  type    = number
  default = 365
}
