########################################################################################################################
## CloudFront distribution
########################################################################################################################

resource "aws_cloudfront_distribution" "default" {
  count               = var.cdn_enabled ? 1 : 0
  comment             = "${title(var.name)} CloudFront Distribution"
  enabled             = true
  is_ipv6_enabled     = true
  aliases             = [var.cdn_domain_name]
  http_version        = "http3" # enables HTTP/3
  default_root_object = "index.html"

  default_cache_behavior {
    # Images don’t need write methods
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true # << gzip/brotli to clients that support it
    target_origin_id       = element(var.cdn_buckets, length(var.cdn_buckets) - 1).name
    viewer_protocol_policy = "redirect-to-https"

    min_ttl     = 0
    default_ttl = 2592000
    max_ttl     = 31536000
    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.cdn_buckets
    iterator = bucket
    content {
      path_pattern           = bucket.value["path"]
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      compress               = true
      target_origin_id       = bucket.value["name"]
      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 2592000  # 30d
      max_ttl                = 31536000 # 1y

      forwarded_values {
        query_string = false # set to true only if you size via ?w=256 etc.
        cookies { forward = "none" }
      }
    }
  }


  dynamic "origin" {
    for_each = var.cdn_buckets
    iterator = bucket

    content {
      domain_name              = bucket.value["domain_name"]
      origin_access_control_id = aws_cloudfront_origin_access_control.default[0].id
      origin_id                = bucket.value["name"]
    }
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cloudfront_certificate[0].arn
    minimum_protocol_version = "TLSv1.2_2021"
    ssl_support_method       = "sni-only"
  }

  tags = local.tags
}

resource "aws_cloudfront_origin_access_control" "default" {
  count                             = var.cdn_enabled ? 1 : 0
  name                              = "default-${var.env}-${var.name}"
  description                       = "Default Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Create CNAME record in Cloudflare pointing CDN domain to CloudFront
resource "cloudflare_record" "cloudfront_domain" {
  count   = var.cdn_enabled ? 1 : 0
  zone_id = data.cloudflare_zone.main.id
  name    = var.cdn_domain_name
  content = aws_cloudfront_distribution.default[0].domain_name
  type    = "CNAME"
  ttl     = 300
  proxied = false
  lifecycle {
    ignore_changes = [content] # Or prevent replacement
  }

  depends_on = [
    aws_cloudfront_distribution.default,
    aws_acm_certificate_validation.cloudfront_certificate
  ]
}

