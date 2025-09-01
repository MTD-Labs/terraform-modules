locals {
  tags = merge({
    env        = var.env
    region     = var.region
    tf-managed = true
    tf-module  = "aws/route53"
  }, var.tags)
}

# data "terraform_remote_state" "vpc" {
#   backend = "s3"
#   config = {
#     bucket = "tf-state-${var.env}"
#     key    = "${var.env}/${var.region}/vpc/terraform.tfstate"
#     region = "us-east-1"
#   }
# }

resource "aws_route53_zone" "private" {
  name = var.route53_zone

  vpc {
    vpc_id = var.vpc_id
  }

  tags = local.tags
}

resource "aws_route53_zone" "private_additional" {
  for_each = toset(var.route53_additional_zone_list)

  name = each.value

  vpc {
    vpc_id = var.vpc_id
  }

  tags = local.tags
}

resource "aws_route53_vpc_association_authorization" "auth" {
  for_each = toset(var.authorized_vpc_list)
  vpc_id   = each.value
  zone_id  = aws_route53_zone.private.zone_id
}

resource "aws_route53_zone_association" "assoc" {
  for_each = toset(var.associated_zone_list)
  vpc_id   = var.vpc_id
  zone_id  = each.value
}
