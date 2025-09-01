resource "aws_ses_domain_identity" "email_identity" {
  domain = var.aws_email_domain
}

resource "aws_ses_domain_dkim" "email_dkim" {
  domain = aws_ses_domain_identity.email_identity.domain
}

resource "aws_ses_domain_mail_from" "mail_from" {
  domain                 = aws_ses_domain_identity.email_identity.domain
  mail_from_domain       = "${var.mail_from_alias}.${var.aws_email_domain}"
  behavior_on_mx_failure = "UseDefaultValue"
}
