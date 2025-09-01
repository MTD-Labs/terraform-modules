data "aws_caller_identity" "current" {}

locals {
  tags = merge({
    Name       = local.name
    Env        = var.env
    tf-managed = true
    tf-module  = "aws/ec2"
  }, var.tags)
  name = "${var.env}-${var.name}"
}

data "aws_ami" "ami" {
  owners      = var.ami_owners
  most_recent = true

  filter {
    name = "name"
    # For Ubuntu 22.04 (Jammy)
    values = [var.ubuntu_ami_name_pattern]
  }

  filter {
    name   = "architecture"
    values = [var.instance_arch]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_iam_policy_document" "secrets_read_policy_doc" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      "arn:aws:secretsmanager:${var.region}:${data.aws_caller_identity.current.account_id}:secret:${var.env}-${var.name}-env*"
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
  name   = "${var.env}-ec2-describe-volumes-policy"
  policy = data.aws_iam_policy_document.ec2_describe_volumes_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "ec2_describe_volumes_attach" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = aws_iam_policy.ec2_describe_volumes_policy.arn
}

resource "aws_iam_policy" "secrets_read_policy" {
  name   = "${var.env}-secrets-read-policy"
  policy = data.aws_iam_policy_document.secrets_read_policy_doc.json
}

resource "aws_iam_role" "ssm_role" {
  name = "${var.env}-SSMRole"
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
  name = var.ssh_authorized_keys_secret
}

data "aws_secretsmanager_secret_version" "env_secret" {
  secret_id = "${var.env}-${var.name}-env"
}

data "aws_secretsmanager_secret_version" "cloudflare_token" {
  secret_id = "${var.env}-${var.name}-cloudflare-token"
  # secret_id = "dev-legally-cloudflare-token"
}

resource "aws_eip" "eip" {
  count             = var.enable_public_access ? 1 : 0
  network_interface = aws_network_interface.public[count.index].id
  tags              = local.tags
}

resource "aws_network_interface" "private" {
  subnet_id       = var.private_subnet_id
  security_groups = [aws_security_group.sg.id]

  tags = merge(
    local.tags,
    {
      subnet = "private"
    }
  )
}

resource "aws_network_interface" "public" {
  count           = var.enable_public_access ? 1 : 0
  subnet_id       = var.public_subnet_id
  security_groups = [aws_security_group.sg.id]

  tags = merge(
    local.tags,
    {
      subnet = "public"
    }
  )
}

resource "aws_ebs_volume" "additional_disk" {
  count             = var.additional_disk ? 1 : 0
  availability_zone = "${var.region}a"
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
}

resource "aws_volume_attachment" "bastion_additional_disk" {
  count       = var.additional_disk ? 1 : 0
  instance_id = aws_instance.bastion.id
  volume_id   = aws_ebs_volume.additional_disk[0].id
  device_name = "/dev/xvdf"
}

resource "aws_instance" "bastion" {
  ami                  = data.aws_ami.ami.id
  ebs_optimized        = true
  instance_type        = var.instance_type
  key_name             = var.key_name
  availability_zone    = "${var.region}a"
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  dynamic "network_interface" {
    for_each = var.enable_public_access == true ? [1] : [0]
    content {
      network_interface_id = aws_network_interface.private.id
      device_index         = network_interface.value
    }
  }

  dynamic "network_interface" {
    for_each = var.enable_public_access == true ? [0] : []
    content {
      network_interface_id = aws_network_interface.public[0].id
      device_index         = network_interface.value
    }
  }

  root_block_device {
    volume_size           = var.ec2_root_volume_size
    delete_on_termination = true
    encrypted             = false
    volume_type           = var.ec2_root_volume_type
    tags = merge(
      local.tags,
      {
        Name = "RootVolume"
      }
    )
  }

  credit_specification {
    cpu_credits = "standard"
  }

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

  lifecycle {
    ignore_changes = [ami]
  }
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
      host        = aws_instance.bastion.public_ip
      user        = "ubuntu"
      private_key = file(var.private_key_path)
    }
  }

  # Force Terraform to create the instance first
  depends_on = [aws_instance.bastion]
}

resource "null_resource" "dev_provisioning" {
  count      = var.env == "dev" ? 1 : 0
  depends_on = [null_resource.wait_for_cloud_init]
  triggers = {
    docker_compose_hash = filesha256("${path.root}/templates/docker-compose.yml")
    nginx_conf_hash     = filesha256("${path.root}/templates/nginx.conf")
    secret_version_id   = data.aws_secretsmanager_secret_version.env_secret.version_id
    cloudflare_token    = data.aws_secretsmanager_secret_version.cloudflare_token.version_id
  }

  provisioner "file" {
    source      = "${path.root}/templates/docker-compose.yml"
    destination = "/app/docker-compose.yml"

    connection {
      type        = "ssh"
      host        = aws_instance.bastion.public_ip
      user        = "ubuntu"
      private_key = file(var.private_key_path)
    }
  }

  provisioner "file" {
    content     = templatefile("${path.root}/templates/nginx.conf", { domain_name = var.domain_name })
    destination = "/app/nginx.conf"

    connection {
      type        = "ssh"
      host        = aws_instance.bastion.public_ip
      user        = "ubuntu"
      private_key = file(var.private_key_path)
    }
  }

  provisioner "file" {
    content     = data.aws_secretsmanager_secret_version.env_secret.secret_string
    destination = "/app/.env"

    connection {
      type        = "ssh"
      host        = aws_instance.bastion.public_ip
      user        = "ubuntu"
      private_key = file(var.private_key_path)
    }
  }

  provisioner "file" {
    content     = data.aws_secretsmanager_secret_version.cloudflare_token.secret_string
    destination = "/app/cloudflare.ini"

    connection {
      type        = "ssh"
      host        = aws_instance.bastion.public_ip
      user        = "ubuntu"
      private_key = file(var.private_key_path)
    }
  }
  provisioner "remote-exec" {
    inline = [
      "aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${var.ecr_user_id}.dkr.ecr.${var.region}.amazonaws.com",
      "cd /app && docker compose up -d"
    ]

    connection {
      type        = "ssh"
      host        = aws_instance.bastion.public_ip
      user        = "ubuntu"
      private_key = file(var.private_key_path)
    }
  }
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "${var.env}-SSMInstanceProfile"
  role = aws_iam_role.ssm_role.name
}
