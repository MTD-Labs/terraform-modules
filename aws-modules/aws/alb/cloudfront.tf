# resource "aws_cloudfront_distribution" "default" {
#   count = var.cdn_optimize_images && var.lambda_edge_enabled == false ? 1 : 0
#   comment             = "${var.cdn_domain_name} CloudFront Distribution"
#   enabled             = true
#   is_ipv6_enabled     = true
#   aliases             = [var.cdn_domain_name]
#   default_root_object = "index.html"

#   # Default Cache Behavior for General Requests
#   default_cache_behavior {
#     target_origin_id       = "s3-origin"
#     viewer_protocol_policy = "redirect-to-https"
#     allowed_methods        = ["GET", "HEAD"]
#     cached_methods         = ["GET", "HEAD"]
#     min_ttl                = 0
#     default_ttl            = 0
#     max_ttl                = 0

#     forwarded_values {
#       query_string = true
#       cookies {
#         forward = "none"
#       }
#     }
#   }

#   # Ordered Cache Behavior for Image Requests
#   ordered_cache_behavior {
#     path_pattern           = "*"
#     target_origin_id       = "s3-origin-group"
#     viewer_protocol_policy = "redirect-to-https"
#     allowed_methods        = ["GET", "HEAD"]
#     cached_methods         = ["GET", "HEAD"]
#     min_ttl                = 0
#     default_ttl            = 0
#     max_ttl                = 0

#     forwarded_values {
#       query_string = true
#       cookies {
#         forward = "none"
#       }
#     }
#   }

#   # Origin for S3 Bucket
#   origin {
#     domain_name = var.cdn_buckets[0].domain_name
#     origin_id   = "s3-origin"

#     origin_access_control_id = aws_cloudfront_origin_access_control.default[0].id
#   }

#   # Lambda Origin via URL
#   origin {
#     domain_name = replace(
#       replace(
#         aws_lambda_function_url.image_resize_url[0].function_url,
#         "https://",
#         ""
#       ),
#       "/",
#       ""
#     )
#     origin_id = "lambda-origin"

#     custom_origin_config {
#       http_port              = 80
#       https_port             = 443
#       origin_protocol_policy = "https-only"
#       origin_ssl_protocols   = ["TLSv1.2"]
#     }
#   }

#   # Origin Group for S3 and Lambda
#   origin_group {
#     origin_id = "s3-origin-group"
#     failover_criteria {
#       status_codes = [404]
#     }

#     member {
#       origin_id = "s3-origin"
#     }

#     member {
#       origin_id = "lambda-origin"
#     }
#   }

#   price_class = "PriceClass_100"

#   restrictions {
#     geo_restriction {
#       restriction_type = "none"
#     }
#   }

#   viewer_certificate {
#     acm_certificate_arn      = aws_acm_certificate.cloudfront_certificate[0].arn
#     minimum_protocol_version = "TLSv1.2_2021"
#     ssl_support_method       = "sni-only"
#   }

#   tags = {
#     Name = "CloudFront Distribution"
#   }
# }

# resource "aws_cloudfront_origin_access_control" "default" {
#   count                             = var.cdn_optimize_images && var.lambda_edge_enabled == false ? 1 : 0
#   name                              = "default-${var.env}"
#   description                       = "Default Policy"
#   origin_access_control_origin_type = "s3"
#   signing_behavior                  = "always"
#   signing_protocol                  = "sigv4"
# }
