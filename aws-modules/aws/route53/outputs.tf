output "main_zone_arn" {
  description = "Main zone ARN"
  value       = aws_route53_zone.private.arn
}

output "main_zone_id" {
  description = "Main zone id"
  value       = aws_route53_zone.private.zone_id
}

output "additional_zone_arn_list" {
  description = "List of additional Route53 zone ARNs"
  value = {
    for zone, spec in aws_route53_zone.private_additional : zone => spec.arn
  }
}

output "additional_zone_id_list" {
  description = "List of additional Route53 zone IDs"
  value = {
    for zone, spec in aws_route53_zone.private_additional : zone => spec.zone_id
  }
}
