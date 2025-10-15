########################################################################################################################
## Certificate for Application Load Balancer including validation via CNAME record
########################################################################################################################
resource "aws_acm_certificate" "alb_certificate" {
  count                     = var.ecs_enabled ? 1 : 0
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  provider                  = aws.main
  validation_method         = "DNS"
  tags                      = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Create DNS validation records in Cloudflare for ALB certificate
resource "cloudflare_record" "alb_cert_validation" {
  for_each = var.ecs_enabled ? {
    for dvo in aws_acm_certificate.alb_certificate[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = var.cloudflare_zone
  name    = each.value.name
  value   = each.value.record
  type    = each.value.type
  ttl     = 60
  proxied = false
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "alb_certificate" {
  count                   = var.ecs_enabled ? 1 : 0
  certificate_arn         = aws_acm_certificate.alb_certificate[0].arn
  validation_record_fqdns = [for record in cloudflare_record.alb_cert_validation : record.hostname]
}

########################################################################################################################
## Certificate for CloudFront Distribution in region us-east-1
########################################################################################################################
resource "aws_acm_certificate" "cloudfront_certificate" {
  count             = var.cdn_enabled ? 1 : 0
  provider          = aws.us_east_1
  domain_name       = var.cdn_domain_name
  validation_method = "DNS"
  tags              = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

# Create DNS validation records in Cloudflare for CloudFront certificate
resource "cloudflare_record" "cloudfront_cert_validation" {
  for_each = var.cdn_enabled ? {
    for dvo in aws_acm_certificate.cloudfront_certificate[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  zone_id = var.cloudflare_zone
  name    = each.value.name
  value   = each.value.record
  type    = each.value.type
  ttl     = 60
  proxied = false
}

# Wait for CloudFront certificate validation to complete
resource "aws_acm_certificate_validation" "cloudfront_certificate" {
  count                   = var.cdn_enabled ? 1 : 0
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront_certificate[0].arn
  validation_record_fqdns = [for record in cloudflare_record.cloudfront_cert_validation : record.hostname]
}