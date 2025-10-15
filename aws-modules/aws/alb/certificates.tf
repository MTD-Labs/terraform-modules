########################################################################################################################
## Certificate for Application Load Balancer including validation via CNAME record
########################################################################################################################
resource "aws_acm_certificate" "alb_certificate" {
  count                     = var.ecs_enabled ? 1 : 0
  domain_name               = var.domain_name
  subject_alternative_names = length(var.subject_alternative_names) > 0 ? var.subject_alternative_names : null
  provider                  = aws.main
  validation_method         = "DNS"
  tags                      = local.tags
  
  lifecycle {
    create_before_destroy = true
  }
}

# Local variable to create a deduplicated list of validation options
locals {
  # Convert to list and deduplicate by resource_record_name
  alb_cert_validation_list = var.ecs_enabled ? [
    for record_name, details in {
      for dvo in aws_acm_certificate.alb_certificate[0].domain_validation_options :
      dvo.resource_record_name => {
        name   = dvo.resource_record_name
        record = dvo.resource_record_value
        type   = dvo.resource_record_type
      }
    } : details
  ] : []
}

# Create DNS validation records in Cloudflare for ALB certificate using count
resource "cloudflare_record" "alb_cert_validation" {
  count = length(local.alb_cert_validation_list)

  zone_id = data.cloudflare_zone.main.id
  name    = local.alb_cert_validation_list[count.index].name
  content = local.alb_cert_validation_list[count.index].record
  type    = local.alb_cert_validation_list[count.index].type
  ttl     = 60
  proxied = false
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "alb_certificate" {
  count                   = var.ecs_enabled ? 1 : 0
  certificate_arn         = aws_acm_certificate.alb_certificate[0].arn
  validation_record_fqdns = cloudflare_record.alb_cert_validation[*].hostname
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

# Local variable for CloudFront validation options
locals {
  cloudfront_cert_validation_list = var.cdn_enabled ? [
    for record_name, details in {
      for dvo in aws_acm_certificate.cloudfront_certificate[0].domain_validation_options :
      dvo.resource_record_name => {
        name   = dvo.resource_record_name
        record = dvo.resource_record_value
        type   = dvo.resource_record_type
      }
    } : details
  ] : []
}

# Create DNS validation records in Cloudflare for CloudFront certificate using count
resource "cloudflare_record" "cloudfront_cert_validation" {
  count = length(local.cloudfront_cert_validation_list)

  zone_id = data.cloudflare_zone.main.id
  name    = local.cloudfront_cert_validation_list[count.index].name
  content = local.cloudfront_cert_validation_list[count.index].record
  type    = local.cloudfront_cert_validation_list[count.index].type
  ttl     = 60
  proxied = false
}

# Wait for CloudFront certificate validation to complete
resource "aws_acm_certificate_validation" "cloudfront_certificate" {
  count                   = var.cdn_enabled ? 1 : 0
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront_certificate[0].arn
  validation_record_fqdns = cloudflare_record.cloudfront_cert_validation[*].hostname
}