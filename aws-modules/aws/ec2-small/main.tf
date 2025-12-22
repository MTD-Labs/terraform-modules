data "aws_caller_identity" "current" {}

data "cloudflare_zone" "this" {
  name = var.cloudflare_zone
}

locals {
  tags = merge({
    Name       = local.name
    Env        = var.env
    tf-managed = true
    tf-module  = "aws/ec2"
  }, var.tags)
  name = "${var.env}-${var.name}"
  target_public_ip = coalesce(
    try(aws_eip.eip[0].public_ip, null),
    try(aws_instance.bastion.public_ip, null)
  )
}

data "aws_iam_policy_document" "secrets_read_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.env}-${var.name}-*"
      # Or even broader:
      # "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.env}-*"
    ]
  }
}

data "aws_iam_policy_document" "ec2_describe_volumes_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeVolumes",
      "ec2:DescribeVolumeAttribute",
      "ec2:DescribeVolumeStatus",
      "ec2:DescribeInstances",
      "ec2:DescribeTags" # Necessary to retrieve tags
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ec2_describe_volumes_policy" {
  name   = "${var.env}-ec2-describe-volumes-policy-${var.region}"
  policy = data.aws_iam_policy_document.ec2_describe_volumes_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "ec2_describe_volumes_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = aws_iam_policy.ec2_describe_volumes_policy.arn
}

resource "aws_iam_policy" "secrets_read_policy" {
  name   = "${var.env}-secrets-read-policy-${var.region}"
  policy = data.aws_iam_policy_document.secrets_read_policy_doc.json
}

resource "aws_iam_role" "ssm_role" {
  name = "${var.env}-SSMRole-${var.region}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "secrets_read_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = aws_iam_policy.secrets_read_policy.arn
}

data "aws_ssm_parameter" "ssh_authorized_keys" {
  # name = "dev-legally-ssh-authorized-keys"
  name   = var.ssh_authorized_keys_secret
  region = var.region
}

data "aws_secretsmanager_secret_version" "services_env" {
  for_each  = toset(var.services_list)
  secret_id = "${var.env}-${each.key}-env"
  region    = var.region
}

data "aws_secretsmanager_secret_version" "cloudflare_token" {
  secret_id = "${var.env}-${var.name}-cloudflare-token"
}

data "aws_subnet" "primary" {
  id = var.enable_public_access ? var.public_subnet_id : var.private_subnet_id
}

# Elastic IP only when public access is enabled
resource "aws_eip" "eip" {
  count  = var.enable_public_access ? 1 : 0
  domain = "vpc"
  tags   = local.tags
}

resource "aws_ebs_volume" "additional_disk" {
  count             = var.additional_disk ? 1 : 0
  availability_zone = data.aws_subnet.primary.availability_zone
  size              = var.additional_disk_size
  type              = var.additional_disk_type
  encrypted         = false

  tags = merge(
    {
      Name = "AdditionalDisk"
      Role = "AdditionalDisk"
    },
    local.tags
  )
  lifecycle {
    ignore_changes = [availability_zone]
  }
}

resource "aws_volume_attachment" "bastion_additional_disk" {
  count       = var.additional_disk ? 1 : 0
  instance_id = aws_instance.bastion.id
  volume_id   = aws_ebs_volume.additional_disk[0].id
  device_name = "/dev/xvdf"
}

resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "this" {
  key_name   = "${var.env}-${var.name}"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "aws_instance" "bastion" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.this.key_name
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  subnet_id                   = var.enable_public_access ? var.public_subnet_id : var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.sg.id]
  associate_public_ip_address = var.enable_public_access

  root_block_device {
    volume_size           = var.ec2_root_volume_size
    delete_on_termination = true
    encrypted             = false
    volume_type           = var.ec2_root_volume_type
    tags                  = merge(local.tags, { Name = "RootVolume" })
  }

  credit_specification { cpu_credits = "standard" }

  user_data = templatefile(
    "${path.module}/templates/user-data.txt",
    {
      ssh_authorized_keys = base64encode(data.aws_ssm_parameter.ssh_authorized_keys.value)
      AWS_DEFAULT_REGION  = var.region
      AWS_ECR_ROOT        = "${var.ecr_user_id}.dkr.ecr.${var.region}.amazonaws.com"
    }
  )

  user_data_replace_on_change = false
  tags                        = local.tags

  depends_on = [
    aws_iam_instance_profile.ssm_profile,
    aws_security_group.sg,
    aws_key_pair.this
  ]

  lifecycle {
    ignore_changes        = [ami]
    create_before_destroy = true
  }

}

# Associate EIP with instance when public access is enabled
resource "aws_eip_association" "eip_assoc" {
  count         = var.enable_public_access ? 1 : 0
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.eip[0].id
}

resource "null_resource" "wait_for_cloud_init" {
  # This resource just ensures the user_data on the instance is done
  provisioner "remote-exec" {
    inline = [
      # Wait until cloud-init finishes processing user-data
      "cloud-init status --wait"
    ]

    connection {
      type        = "ssh"
      host        = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
      user        = "ubuntu"
      private_key = tls_private_key.ssh.private_key_openssh
    }
  }

  # Force Terraform to create the instance first
  depends_on = [aws_instance.bastion, aws_eip_association.eip_assoc]
}

resource "null_resource" "service_env_files" {
  for_each   = data.aws_secretsmanager_secret_version.services_env
  depends_on = [null_resource.wait_for_cloud_init]

  triggers = {
    version_id  = each.value.version_id
    instance_id = aws_instance.bastion.id
  }

  provisioner "file" {
    content     = each.value.secret_string
    destination = "/app/.env.${each.key}"

    connection {
      type        = "ssh"
      host        = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
      user        = "ubuntu"
      private_key = tls_private_key.ssh.private_key_openssh
    }
  }
}

resource "null_resource" "dev_provisioning" {
  count = contains(["stage", "qa"], var.env) ? 1 : 0
  depends_on = [null_resource.wait_for_cloud_init, null_resource.service_env_files]
  triggers = {
    # Force recreation when any of these files change
    docker_compose_hash = filesha256("${path.root}/templates/docker-compose.yml")
    nginx_conf_hash     = filesha256("${path.root}/templates/nginx.conf")
    cloudflare_token    = data.aws_secretsmanager_secret_version.cloudflare_token.version_id
    nginx_dockerfile    = filesha256("${path.root}/templates/Dockerfile.nginx")
    loki_config         = filesha256("${path.root}/templates/loki-config.yml")
    promtail_config     = filesha256("${path.root}/templates/promtail-config.yml")
    grafana_loki_source = filesha256("${path.root}/templates/grafana-provisioning/datasources/loki.yml")

    # Add this to force recreation when env files change
    env_files_version = join(",", [for k, v in data.aws_secretsmanager_secret_version.services_env : v.version_id])

    # Add instance ID to ensure recreation if instance is replaced
    instance_id = aws_instance.bastion.id
  }

  provisioner "file" {
    source      = "${path.root}/templates/Dockerfile.nginx"
    destination = "/app/Dockerfile.nginx"

    connection {
      type        = "ssh"
      host        = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
      user        = "ubuntu"
      private_key = tls_private_key.ssh.private_key_openssh
    }
  }

  provisioner "file" {
    source      = "${path.root}/templates/loki-config.yml"
    destination = "/app/loki-config.yml"

    connection {
      type        = "ssh"
      host        = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
      user        = "ubuntu"
      private_key = tls_private_key.ssh.private_key_openssh
    }
  }

  provisioner "file" {
    source      = "${path.root}/templates/promtail-config.yml"
    destination = "/app/promtail-config.yml"

    connection {
      type        = "ssh"
      host        = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
      user        = "ubuntu"
      private_key = tls_private_key.ssh.private_key_openssh
    }
  }

  provisioner "file" {
    source      = "${path.root}/templates/grafana-provisioning/datasources/loki.yml"
    destination = "/app/grafana-provisioning/datasources/loki.yml"

    connection {
      type        = "ssh"
      host        = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
      user        = "ubuntu"
      private_key = tls_private_key.ssh.private_key_openssh
    }
  }

  provisioner "file" {
    source      = "${path.root}/templates/docker-compose.yml"
    destination = "/app/docker-compose.yml"

    connection {
      type        = "ssh"
      host        = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
      user        = "ubuntu"
      private_key = tls_private_key.ssh.private_key_openssh
    }
  }

  provisioner "file" {
    content     = templatefile("${path.root}/templates/nginx.conf", { domain_name = var.domain_name })
    destination = "/app/nginx.conf"

    connection {
      type        = "ssh"
      host        = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
      user        = "ubuntu"
      private_key = tls_private_key.ssh.private_key_openssh
    }
  }
  provisioner "file" {
    content     = data.aws_secretsmanager_secret_version.cloudflare_token.secret_string
    destination = "/app/cloudflare.ini"

    connection {
      type        = "ssh"
      host        = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
      user        = "ubuntu"
      private_key = tls_private_key.ssh.private_key_openssh
    }
  }
  provisioner "remote-exec" {
    inline = [
      "aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${var.ecr_user_id}.dkr.ecr.${var.region}.amazonaws.com",
      "cd /app && docker compose pull",
      # Recreate only services that have mounted env files
      "cd /app && docker compose up -d --force-recreate --no-deps trendex-backend trendex-public-frontend trendex-admin-frontend",
      # Start all other services normally (they won't recreate if nothing changed)
      "cd /app && docker compose up -d --remove-orphans"
    ]

    connection {
      type        = "ssh"
      host        = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
      user        = "ubuntu"
      private_key = tls_private_key.ssh.private_key_openssh
    }
  }
  provisioner "remote-exec" {
    inline = [
      "docker restart nginx"
    ]

    connection {
      type        = "ssh"
      host        = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
      user        = "ubuntu"
      private_key = tls_private_key.ssh.private_key_openssh
    }
  }
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.env}-SSMInstanceProfile-${var.region}"
  role = aws_iam_role.ssm_role.name
}

resource "cloudflare_record" "stage_a" {
  count           = var.cloudflare_record_enable ? 1 : 0
  zone_id         = data.cloudflare_zone.this.id
  name            = var.env
  type            = "A"
  content         = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
  ttl             = 1
  proxied         = var.cloudflare_proxied
  allow_overwrite = true
  depends_on      = [aws_instance.bastion, aws_eip_association.eip_assoc]
}

resource "cloudflare_record" "stage_wildcard_a" {
  count           = var.cloudflare_record_enable ? 1 : 0
  zone_id         = data.cloudflare_zone.this.id
  name            = "*.${var.env}"
  type            = "A"
  content         = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
  ttl             = 1
  proxied         = false
  allow_overwrite = true
  depends_on      = [aws_instance.bastion, aws_eip_association.eip_assoc]
}
