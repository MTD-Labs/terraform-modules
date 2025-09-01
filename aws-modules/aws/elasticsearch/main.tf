locals {
  name = var.name == "" ? "${var.env}-elasticsearch" : "${var.env}-elasticsearch-${var.name}"
  tags = merge({
    Name       = local.name
    env        = var.env
    tf-managed = true
    tf-module  = "aws/elasticsearch"
  }, var.tags)
}

resource "aws_elasticsearch_domain" "elasticsearch" {
  domain_name           = local.name
  elasticsearch_version = var.elasticsearch_version

  cluster_config {
    instance_type          = var.instance_type
    instance_count         = 1
    zone_awareness_enabled = false
  }

  ebs_options {
    ebs_enabled = true
    volume_size = var.ebs_volume_size
    volume_type = "gp2"
  }

  vpc_options {
    security_group_ids = [aws_security_group.elasticsearch_sg.id]
    subnet_ids         = var.subnets
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "es:*"
        Resource  = "*"
      }
    ]
  })

  tags = local.tags
}

resource "aws_security_group" "elasticsearch_sg" {
  name        = "${local.name}-sg"
  description = "Security group for Elasticsearch"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = local.tags
}
