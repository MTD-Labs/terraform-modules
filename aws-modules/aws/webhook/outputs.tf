output "webhook_url" {
  description = "Public webhook URL for Alchemy (HTTP POST)"
  value       = "${aws_apigatewayv2_stage.api.invoke_url}${var.webhook_path_prefix}/${random_uuid.webhook_token.result}"
}

output "rabbitmq_amqps_endpoint" {
  description = "amqps endpoint of the Amazon MQ broker"
  value       = aws_mq_broker.rabbit.instances[0].endpoints[0]
}

output "rabbitmq_broker_id" {
  description = "RabbitMQ broker ID"
  value       = aws_mq_broker.rabbit.id
}

output "signing_secret_resolved_arn" {
  description = "Resolved ARN of the Alchemy signing secret (by name)."
  value       = data.aws_secretsmanager_secret.alchemy_signing_key.arn
}
