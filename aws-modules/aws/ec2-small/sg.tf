resource "aws_security_group" "sg" {
  name        = "${var.env}-${local.name}-ec2"
  description = "Security group for ${local.name}."
  vpc_id      = var.vpc_id

  # Dynamically allow all ports defined in allowed_tcp_ports
  dynamic "ingress" {
    for_each = var.allowed_tcp_ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  # Additional static ingress rule: 3000
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }

  # Additional static ingress rule: 8000 (open to all)
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}
