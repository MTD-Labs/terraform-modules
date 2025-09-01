resource "aws_security_group" "sg" {
  name        = "${local.name}-ec2"
  description = "Security group for ${local.name}."
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_tcp_ports
    iterator = port
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "tcp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  dynamic "ingress" {
    for_each = var.allowed_udp_ports
    iterator = port
    content {
      from_port   = port.value
      to_port     = port.value
      protocol    = "udp"
      cidr_blocks = var.allowed_cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags

}
