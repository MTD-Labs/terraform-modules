# main.tf — create empty Secrets Manager secrets (no values)

resource "aws_secretsmanager_secret" "secrets" {
  for_each = var.aws_secrets_list

  name                    = each.key
  description             = each.value.description
  recovery_window_in_days = each.value.recovery_window_in_days

  # Optional: choose a KMS key if you don't want the default account key
  # kms_key_id = each.value.kms_key_id

  tags = merge(
    each.value.tags,
    { ManagedBy = "Terraform" }
  )
}

# (Optional) guardrail to enforce allowed types
locals {
  allowed_secret_types = ["plaintext", "key_value"]
}
