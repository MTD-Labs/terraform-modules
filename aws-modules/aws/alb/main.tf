data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  name       = "${var.env}-${var.name}"

  common_tags = {
    Env        = var.env
    tf-managed = true
    tf-module  = "aws/alb"
  }

  tags = merge({
    Name = local.name
  }, local.common_tags, var.tags)
}

resource "aws_alb" "alb" {
  count           = var.ecs_enabled ? 1 : 0
  name            = local.name
  security_groups = [aws_security_group.alb[0].id]
  subnets         = var.vpc_subnets

  idle_timeout = var.idle_timeout

  tags = local.tags
}


resource "aws_alb_listener" "alb_default_listener_http" {
  count             = var.ecs_enabled ? 1 : 0
  load_balancer_arn = aws_alb.alb[0].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = local.tags
}

resource "aws_alb_listener" "alb_default_listener_https" {
  count             = var.ecs_enabled ? 1 : 0
  load_balancer_arn = aws_alb.alb[0].arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.alb_certificate[0].arn
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Access denied"
      status_code  = "403"
    }
  }

  tags = local.tags

  depends_on = [aws_acm_certificate_validation.alb_certificate]

}

resource "aws_security_group" "alb" {
  count       = var.ecs_enabled ? 1 : 0
  name        = local.name
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all egress traffic"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow ingress HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow ingress HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}
### In case of ALB origin in Cloudfront:
#
# data "aws_ec2_managed_prefix_list" "cloudfront" {
#   name = "com.amazonaws.global.cloudfront.origin-facing"
# }

# resource "aws_security_group_rule" "alb_cloudfront_https_ingress_only" {
#   security_group_id = aws_security_group.alb.id
#   description       = "Allow HTTPS access only from CloudFront CIDR blocks"
#   from_port         = 443
#   protocol          = "tcp"
#   prefix_list_ids   = [data.aws_ec2_managed_prefix_list.cloudfront.id]
#   to_port           = 443
#   type              = "ingress"
# }

# Create CNAME record in Cloudflare pointing domain to ALB
data "cloudflare_zone" "main" {
  name = var.cloudflare_zone
}

# Create CNAME record in Cloudflare pointing main domain to ALB
resource "cloudflare_record" "alb_domain" {
  count   = var.ecs_enabled ? 1 : 0
  zone_id = data.cloudflare_zone.main.id
  name    = var.domain_name
  content = aws_alb.alb[0].dns_name
  type    = "CNAME"
  ttl     = 300
  proxied = false

  depends_on = [
    aws_alb.alb,
    aws_acm_certificate_validation.alb_certificate
  ]
}

# Create CNAME records for all subject alternative names
resource "cloudflare_record" "alb_san_domains" {
  for_each = var.ecs_enabled ? toset(var.subject_alternative_names) : []
  
  zone_id = data.cloudflare_zone.main.id
  name    = each.value
  content = aws_alb.alb[0].dns_name
  type    = "CNAME"
  ttl     = 300
  proxied = false

  depends_on = [
    aws_alb.alb,
    aws_acm_certificate_validation.alb_certificate
  ]
}
