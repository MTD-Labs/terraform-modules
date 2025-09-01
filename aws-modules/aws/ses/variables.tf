variable "aws_email_domain" {
  description = "Domain for AWS Email Service"
  type        = string
  default     = "exmaple.com"
}


variable "mail_from_alias" {
  description = "Alias for Email from"
  type        = string
  default     = "user"
}

variable "tags" {
  type    = map(string)
  default = null
}