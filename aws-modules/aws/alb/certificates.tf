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

# Local variable to create a clean list of validation options with deduplication
locals {
  alb_cert_validation_options = var.ecs_enabled ? distinct([
    for dvo in aws_acm_certificate.alb_certificate[0].domain_validation_options : {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  ]) : []
  
  # Create a map to deduplicate by resource_record_name
  alb_cert_validation_map = var.ecs_enabled ? {
    for dvo in aws_acm_certificate.alb_certificate[0].domain_validation_options :
    dvo.resource_record_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}
}

# Create DNS validation records in Cloudflare for ALB certificate
resource "cloudflare_record" "alb_cert_validation" {
  for_each = local.alb_cert_validation_map

  zone_id = data.cloudflare_zone.main.id
  name    = each.value.name
  content = each.value.record
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

# Local variable for CloudFront validation options with deduplication
locals {
  cloudfront_cert_validation_map = var.cdn_enabled ? {
    for dvo in aws_acm_certificate.cloudfront_certificate[0].domain_validation_options :
    dvo.resource_record_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}
}

# Create DNS validation records in Cloudflare for CloudFront certificate
resource "cloudflare_record" "cloudfront_cert_validation" {
  for_each = local.cloudfront_cert_validation_map

  zone_id = data.cloudflare_zone.main.id
  name    = each.value.name
  content = each.value.record
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
