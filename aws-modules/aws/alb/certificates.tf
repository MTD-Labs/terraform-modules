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

# Use known domains to create static keys for ALB certificate
locals {
  # All domains that need validation (deduplicated)
  alb_domains_for_validation = var.ecs_enabled ? toset(concat(
    [var.domain_name],
    var.subject_alternative_names
  )) : []
}

# Create DNS validation records in Cloudflare for ALB certificate
resource "cloudflare_record" "alb_cert_validation" {
  for_each = local.alb_domains_for_validation

  zone_id = data.cloudflare_zone.main.id

  # Find the validation options for this domain
  name = length([
    for dvo in aws_acm_certificate.alb_certificate[0].domain_validation_options :
    dvo if dvo.domain_name == each.key
    ]) > 0 ? [
    for dvo in aws_acm_certificate.alb_certificate[0].domain_validation_options :
    dvo.resource_record_name if dvo.domain_name == each.key
  ][0] : ""

  content = length([
    for dvo in aws_acm_certificate.alb_certificate[0].domain_validation_options :
    dvo if dvo.domain_name == each.key
    ]) > 0 ? [
    for dvo in aws_acm_certificate.alb_certificate[0].domain_validation_options :
    dvo.resource_record_value if dvo.domain_name == each.key
  ][0] : ""

  type = length([
    for dvo in aws_acm_certificate.alb_certificate[0].domain_validation_options :
    dvo if dvo.domain_name == each.key
    ]) > 0 ? [
    for dvo in aws_acm_certificate.alb_certificate[0].domain_validation_options :
    dvo.resource_record_type if dvo.domain_name == each.key
  ][0] : ""

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

# Create single DNS validation record for CloudFront certificate (only one domain)
resource "cloudflare_record" "cloudfront_cert_validation" {
  count   = var.cdn_enabled ? 1 : 0
  zone_id = data.cloudflare_zone.main.id
  name    = tolist(aws_acm_certificate.cloudfront_certificate[0].domain_validation_options)[0].resource_record_name
  content = tolist(aws_acm_certificate.cloudfront_certificate[0].domain_validation_options)[0].resource_record_value
  type    = tolist(aws_acm_certificate.cloudfront_certificate[0].domain_validation_options)[0].resource_record_type
  ttl     = 60
  proxied = false
}

# Wait for CloudFront certificate validation to complete
resource "aws_acm_certificate_validation" "cloudfront_certificate" {
  count                   = var.cdn_enabled ? 1 : 0
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.cloudfront_certificate[0].arn
  validation_record_fqdns = [cloudflare_record.cloudfront_cert_validation[0].hostname]
}