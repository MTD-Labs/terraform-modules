# Amazon MQ Broker outputs
output "broker_arn" {
  description = "Amazon Resource Name (ARN) of the broker"
  value       = aws_mq_broker.amazon_mq.arn
}

output "broker_id" {
  description = "The unique ID that Amazon MQ generates for the broker"
  value       = aws_mq_broker.amazon_mq.id
}

output "broker_name" {
  description = "The name of the broker"
  value       = aws_mq_broker.amazon_mq.broker_name
}

output "broker_instances" {
  description = "A list of information about allocated brokers"
  value       = aws_mq_broker.amazon_mq.instances
}

output "broker_endpoints" {
  description = "Map of broker endpoints"
  value = {
    console      = try(aws_mq_broker.amazon_mq.instances[0].console_url, "")
    stomp_ssl    = try(aws_mq_broker.amazon_mq.instances[0].endpoints[0], "")
    stomp        = try(aws_mq_broker.amazon_mq.instances[0].endpoints[1], "")
    openwire_ssl = try(aws_mq_broker.amazon_mq.instances[0].endpoints[2], "")
    openwire     = try(aws_mq_broker.amazon_mq.instances[0].endpoints[3], "")
    amqp_ssl     = try(aws_mq_broker.amazon_mq.instances[0].endpoints[4], "")
    amqp         = try(aws_mq_broker.amazon_mq.instances[0].endpoints[5], "")
    mqtt_ssl     = try(aws_mq_broker.amazon_mq.instances[0].endpoints[6], "")
    mqtt         = try(aws_mq_broker.amazon_mq.instances[0].endpoints[7], "")
    wss          = try(aws_mq_broker.amazon_mq.instances[0].endpoints[8], "")
  }
}

output "admin_username" {
  description = "The admin username"
  value       = var.admin_username
  sensitive   = true
}

output "admin_password" {
  description = "The admin password"
  value       = random_password.admin_password.result
  sensitive   = true
}

output "admin_password_ssm_arn" {
  description = "The admin password ARN in Parameter Store"
  value       = aws_ssm_parameter.admin_password.arn
}

output "user_passwords" {
  description = "Map of user passwords"
  value = {
    for user in var.users : user => random_password.user_password[user].result
  }
  sensitive = true
}

output "user_password_ssm_arns" {
  description = "Map of user password ARNs in Parameter Store"
  value = {
    for user in var.users : user => aws_ssm_parameter.user_passwords[user].arn
  }
}

output "security_group_id" {
  description = "The security group ID of the Amazon MQ broker"
  value       = aws_security_group.mq_security_group.id
}