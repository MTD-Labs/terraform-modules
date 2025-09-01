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

output "instance_id" {
  description = "Instance ID"
  value       = aws_instance.bastion.id # Use the splat operator to get a list of IDs
}
