########################################################################################################################
## Certificate for Application Load Balancer including validation via CNAME record
########################################################################################################################
resource "aws_acm_certificate" "ingress_certificate" {
  domain_name               = var.domain_name
  provider                  = aws.main
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

