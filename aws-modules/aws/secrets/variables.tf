variable "aws_secrets_list" {
  description = "Secrets to create (metadata only; no values)"
  type = map(object({
    description             = string
    type                    = string # kept for intent: "plaintext" | "key_value"
    recovery_window_in_days = optional(number, 30)
    tags                    = optional(map(string), {})
    kms_key_id              = optional(string)
  }))

  default = {}
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
