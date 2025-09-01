output "security_group_id" {
  description = "Security group id."
  value       = aws_security_group.sg.id
}

output "public_ip" {
  description = "Public IP."
  value       = aws_eip.eip.*.public_ip
}

output "private_ip" {
  description = "Public IP."
  value       = aws_instance.bastion.private_ip
}

# output "private_key_pem" {
#   value     = tls_private_key.private_key.private_key_pem
#   sensitive = true
# }
