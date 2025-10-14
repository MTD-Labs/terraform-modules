variable "region" {
  type    = string
  default = "me-south-1"
}

variable "lambda_region" {
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

variable "vpc_subnets" {
  type = list(string)
}

variable "domain_name" {
  type = string
}

variable "idle_timeout" {
  type = number
}

variable "cdn_enabled" {
  type    = bool
  default = true
}

variable "cdn_domain_name" {
  type = string
}

variable "cdn_optimize_images" {
  type    = bool
  default = false
}

# variable "cdn_bucket_names" {
#   type = list(string)
# }

variable "cdn_buckets" {
  type = list(map(string))
  default = [
    {
      name        = "static"
      domain_name = "static.s3.us-east-1.amazonaws.com"
      prefix      = "/*"
    }
    # Add more buckets as needed
  ]
}

variable "lambda_image_url" {
  type    = string
  default = ""
}

variable "lambda_memory_size" {
  type    = number
  default = 128
}

variable "lambda_private_subnets" {
  type = list(string)
}

variable "lambda_security_group" {
  type = list(string)
}

variable "ecs_enabled" {
  type    = bool
  default = false
}

variable "lambda_bucket_name" {
  type    = string
  default = ""
}

variable "ssm_secret_key" {
  type    = string
  default = ""
}

variable "document_data_api_url" {
  type    = string
  default = ""
}

variable "html_to_pdf_url" {
  type    = string
  default = ""
}

variable "html_to_docx_url" {
  type    = string
  default = ""
}

variable "lambda_edge_enabled" {
  type    = bool
  default = false
}

variable "subject_alternative_names" {
  description = "Additional domain names to include in the certificate"
  type        = list(string)
  default     = []
}
