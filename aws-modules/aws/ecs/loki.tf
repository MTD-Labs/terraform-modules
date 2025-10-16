# loki.tf - Updated version

# EC2 instance for Loki and Grafana
resource "aws_instance" "loki_grafana" {
  count                  = var.loki_enabled ? 1 : 0
  ami                    = data.aws_ami.ubuntu[count.index].id
  instance_type          = var.loki_ec2_instance_type
  key_name               = var.loki_ec2_key_name
  subnet_id              = var.vpc_subnets[0]
  vpc_security_group_ids = [aws_security_group.loki_grafana[0].id]

  tags = merge({
    Name = "${var.cluster_name}-loki-grafana"
  }, local.common_tags)

  user_data = templatefile("${path.module}/loki-grafana-setup.sh", {
    grafana_domain         = var.grafana_domain
    grafana_admin_password = var.grafana_admin_password
    alert_manager_url      = var.alert_manager_url
  })

  root_block_device {
    volume_size = var.loki_instance_volume_size
    volume_type = "gp3"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# Elastic IP for Loki instance
resource "aws_eip" "loki_grafana" {
  count    = var.loki_enabled ? 1 : 0
  instance = aws_instance.loki_grafana[0].id
  domain   = "vpc"

  tags = merge({
    Name = "${var.cluster_name}-loki-grafana-eip"
  }, local.common_tags)
}

# Security group for Loki and Grafana
resource "aws_security_group" "loki_grafana" {
  count       = var.loki_enabled ? 1 : 0
  name        = "${var.cluster_name}-loki-grafana"
  description = "Security group for Loki and Grafana EC2 instance"
  vpc_id      = var.vpc_id

  # Allow Loki (3100) from private CIDRs
  ingress {
    from_port   = 3100
    to_port     = 3100
    protocol    = "tcp"
    cidr_blocks = var.vpc_private_cidr_blocks
    description = "Loki API from private CIDRs"
  }

  # SSH (consider restricting to your office IPs)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({ Name = "${var.cluster_name}-loki-grafana" }, local.common_tags)
}

# Allow ALB SG to reach Grafana (3000) via SG-to-SG rule
resource "aws_security_group_rule" "grafana_from_alb" {
  count                    = var.loki_enabled ? 1 : 0
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.loki_grafana[0].id
  source_security_group_id = var.alb_security_group_id
  description              = "ALB Grafana 3000"
}

resource "aws_security_group_rule" "loki_from_ecs_tasks" {
  for_each = { for idx, container in var.containers : idx => container }
  count                    = var.loki_enabled ? 1 : 0
  type                     = "ingress"
  from_port                = 3100
  to_port                  = 3100
  protocol                 = "tcp"
  security_group_id        = aws_security_group.loki_grafana[0].id
  source_security_group_id = aws_security_group.ecs[each.key].id
  description              = "Loki access from ${each.value.name} ECS tasks"
}

# Target group for Grafana
resource "aws_alb_target_group" "grafana" {
  count       = var.loki_enabled ? 1 : 0
  name        = "${var.cluster_name}-grafana"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = merge({
    Name = "${var.cluster_name}-grafana"
  }, local.common_tags)
}

# Listener rule for Grafana
resource "aws_alb_listener_rule" "grafana" {
  count        = var.loki_enabled ? 1 : 0
  listener_arn = var.alb_listener_arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.grafana[0].arn
  }

  condition {
    host_header {
      values = [var.grafana_domain]
    }
  }

  tags = merge({
    Name = "${var.cluster_name}-grafana"
  }, local.common_tags)
}

# Target group attachment for Grafana
resource "aws_alb_target_group_attachment" "grafana" {
  count            = var.loki_enabled ? 1 : 0
  target_group_arn = aws_alb_target_group.grafana[0].arn
  target_id        = aws_instance.loki_grafana[0].id
  port             = 3000
}

# IAM policy for ECS tasks to write to Loki
resource "aws_iam_policy" "ecs_loki_logging" {
  count       = var.loki_enabled ? 1 : 0
  name        = "${var.cluster_name}-ecs-loki-logging"
  description = "Allows ECS tasks to send logs to Loki"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach Loki logging policy to task role
resource "aws_iam_role_policy_attachment" "ecs_loki_logging" {
  count      = var.loki_enabled ? 1 : 0
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.ecs_loki_logging[0].arn
}

# Data source for Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
  count       = var.loki_enabled ? 1 : 0
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS account ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# OUTPUTS - Add these to expose the Loki IP
# output "loki_private_ip" {
#   value       = var.loki_enabled && length(aws_instance.loki_grafana) > 0 ? aws_instance.loki_grafana[0].private_ip : null
#   description = "Private IP address of the Loki instance"
# }

# output "loki_public_ip" {
#   value       = var.loki_enabled && length(aws_eip.loki_grafana) > 0 ? aws_eip.loki_grafana[0].public_ip : null
#   description = "Public IP address of the Loki instance for SSH access"
# }