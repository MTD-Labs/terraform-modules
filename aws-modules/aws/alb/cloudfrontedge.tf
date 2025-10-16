########################################################################################################################
## CloudFront distribution
########################################################################################################################

resource "aws_cloudfront_distribution" "default_edge" {
  count           = var.cdn_enabled && var.lambda_edge_enabled ? 1 : 0
  comment         = "${title(var.name)} CloudFront Distribution"
  enabled         = true
  is_ipv6_enabled = true
  aliases         = [var.cdn_domain_name]

  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD", "OPTIONS"]
    target_origin_id       = element(var.cdn_buckets, length(var.cdn_buckets) - 1).name
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.cdn_buckets
    iterator = bucket

    content {
      path_pattern           = bucket.value["path"]
      allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods         = ["GET", "HEAD", "OPTIONS"]
      target_origin_id       = bucket.value["name"]
      viewer_protocol_policy = "redirect-to-https"
      min_ttl                = 0
      default_ttl            = 3600
      max_ttl                = 86400

      forwarded_values {
        query_string = false

        cookies {
          forward = "none"
        }
      }

      dynamic "lambda_function_association" {
        # Only add the association if cdn_optimize_images AND lambda_edge_enabled are both true
        for_each = var.cdn_optimize_images && var.lambda_edge_enabled ? [1] : []

        content {
          event_type = "origin-response"
          lambda_arn = aws_lambda_function.image_resize_edge[count.index].qualified_arn
        }
      }

    }
  }

  dynamic "origin" {
    for_each = var.cdn_buckets
    iterator = bucket

    content {
      domain_name              = bucket.value["domain_name"]
      origin_access_control_id = aws_cloudfront_origin_access_control.default_edge[0].id
      origin_id                = bucket.value["name"]
    }
  }

  # origin {
  #   domain_name              = var.cdn_bucket_names[0]
  #   origin_access_control_id = aws_cloudfront_origin_access_control.default.id
  #   origin_id                = local.s3_origin_id
  # }

  ### This is ALB origin example

  # origin {
  #   domain_name = aws_alb.alb.dns_name
  #   origin_id   = aws_alb.alb.name

  #   custom_header {
  #     name  = "X-Custom-Header"
  #     value = var.custom_origin_host_header
  #   }

  #   custom_origin_config {
  #     origin_read_timeout      = 60
  #     origin_keepalive_timeout = 60
  #     http_port                = 80
  #     https_port               = 443
  #     origin_protocol_policy   = "https-only"
  #     origin_ssl_protocols     = ["TLSv1", "TLSv1.1", "TLSv1.2"]
  #   }
  # }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # viewer_certificate {
  #   cloudfront_default_certificate = true
  # }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cloudfront_certificate[0].arn
    minimum_protocol_version = "TLSv1.1_2016"
    ssl_support_method       = "sni-only"
  }

  tags = local.tags
}

resource "aws_cloudfront_origin_access_control" "default_edge" {
  count                             = var.cdn_enabled && var.lambda_edge_enabled ? 1 : 0
  name                              = "default"
  description                       = "Default Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
