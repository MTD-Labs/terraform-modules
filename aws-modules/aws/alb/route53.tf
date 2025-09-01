# resource "aws_route53_zone" "service" {
#   name = var.domain_name
# }

# resource "aws_route53_record" "record" {
#   name    = var.domain_name
#   type    = "A"
#   zone_id = aws_route53_zone.service.id

#   alias {
#     name                   = aws_cloudfront_distribution.default.domain_name
#     zone_id                = aws_cloudfront_distribution.default.hosted_zone_id
#     evaluate_target_health = false
#   }
# }
