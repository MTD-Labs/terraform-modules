locals {
  tags = merge({
    Name       = local.name
    Env        = var.env
    tf-managed = true
    tf-module  = "aws/ec2"
  }, var.tags)
  name = "${var.env}-${var.name}"

  # Hash for the whole grafana dir so changes trigger re-provision
  grafana_files = fileset("${path.root}/templates/grafana", "**")
  grafana_hash = sha1(join(",", [
    for f in local.grafana_files : filesha256("${path.root}/templates/grafana/${f}")
  ]))
}

data "aws_ami" "ami" {
  most_recent = "true"
  dynamic "filter" {
    for_each = var.ami_filter
    content {
      name   = filter.key
      values = filter.value
    }
  }
  owners = var.ami_owners
}

data "aws_ssm_parameter" "ssh_authorized_keys" {
  name = var.ssh_authorized_keys_secret
}

# Create network interfaces
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

# Create EC2 instance
resource "aws_instance" "bastion" {
  ami               = data.aws_ami.ami.id
  ebs_optimized     = true
  instance_type     = var.instance_type
  availability_zone = "${var.region}a"

  # Primary network interface at launch (required)
  network_interface {
    network_interface_id = var.enable_public_access ? aws_network_interface.public[0].id : aws_network_interface.private.id
    device_index         = 0
  }

  # Secondary network interface (only when public access is enabled)
  dynamic "network_interface" {
    for_each = var.enable_public_access ? [1] : []
    content {
      network_interface_id = aws_network_interface.private.id
      device_index         = 1
    }
  }

  root_block_device {
    volume_size           = 10
    delete_on_termination = true
    encrypted             = false
    volume_type           = "gp2"
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

  user_data_replace_on_change = true
  tags                        = local.tags
  volume_tags                 = local.tags

  lifecycle {
    ignore_changes = [ami]
  }
}

# Create EIP
resource "aws_eip" "eip" {
  count  = var.enable_public_access ? 1 : 0
  domain = "vpc"
  tags   = local.tags
}

# Associate EIP with the public network interface
resource "aws_eip_association" "eip_assoc" {
  count                = var.enable_public_access ? 1 : 0
  allocation_id        = aws_eip.eip[0].id
  network_interface_id = aws_network_interface.public[0].id

  depends_on = [aws_instance.bastion]
}

############################################
# ⏳ Wait for cloud-init (so SSH is ready)
############################################
resource "null_resource" "wait_for_cloud_init" {
  # Use instance id to force re-run when instance is replaced
  count = var.grafana_enabled ? 1 : 0
  triggers = {
    instance_id = aws_instance.bastion.id
  }

  provisioner "remote-exec" {
    inline = [
      # Wait until cloud-init finishes processing user-data
      "cloud-init status --wait"
    ]

    connection {
      type = "ssh"
      user = "ubuntu"
      host = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
      # Use your local SSH agent for the private key that matches the public key you inject
      agent = true
      # If you prefer passing a key directly, use:
      # private_key = file(var.path_to_private_key)
    }
  }

  depends_on = [
    aws_instance.bastion,
    aws_eip_association.eip_assoc
  ]
}


data "aws_secretsmanager_secret_version" "grafana-prod" {
  secret_id = "${var.env}-grafana-env"
}

############################################
# 📦 Copy templates/grafana → /app/grafana
############################################
resource "null_resource" "copy_grafana_tree" {
  depends_on = [null_resource.wait_for_cloud_init]
  count      = var.grafana_enabled ? 1 : 0

  triggers = {
    # re-run whenever grafana files change or instance is replaced
    grafana_hash = local.grafana_hash
    instance_id  = aws_instance.bastion.id
    version_id   = data.aws_secretsmanager_secret_version.grafana-prod.version_id
  }

  # Ensure destination exists
  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /app/grafana",
      "sudo chown -R ubuntu:ubuntu /app"
    ]
    
    connection {
      type  = "ssh"
      user  = "ubuntu"
      host  = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
      agent = true
    }
  }

  # Copy the directory recursively
  provisioner "file" {
    source      = "${path.root}/templates/grafana"
    destination = "/app" # results in /app/grafana

    connection {
      type  = "ssh"
      user  = "ubuntu"
      host  = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
      agent = true
    }
  }

  # Copy .env file from secrets manager
  provisioner "file" {
    content     = data.aws_secretsmanager_secret_version.grafana-prod.secret_string
    destination = "/app/grafana/.env"
    
    connection {
      type  = "ssh"
      user  = "ubuntu"
      host  = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
      agent = true
    }
  }

  # Set proper permissions after copying
  provisioner "remote-exec" {
    inline = [
      "chmod 600 /app/grafana/.env",
      "sudo chown -R ubuntu:ubuntu /app/grafana"
    ]
    
    connection {
      type  = "ssh"
      user  = "ubuntu"
      host  = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
      agent = true
    }
  }
}

############################################
# 🐳 Compose up (in /app/grafana)
############################################
resource "null_resource" "grafana_compose_up" {
  depends_on = [null_resource.copy_grafana_tree]
  count      = var.grafana_enabled ? 1 : 0
  triggers = {
    grafana_hash = local.grafana_hash
    instance_id  = aws_instance.bastion.id
  }

  provisioner "remote-exec" {
    inline = [
      # Optional: login to a registry if needed
      # "aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${var.ecr_user_id}.dkr.ecr.${var.region}.amazonaws.com",

      "cd /app/grafana && docker compose pull",
      "cd /app/grafana && docker compose up -d --remove-orphans"
    ]

    connection {
      type  = "ssh"
      user  = "ubuntu"
      host  = var.enable_public_access ? aws_eip.eip[0].public_ip : aws_instance.bastion.private_ip
      agent = true
    }
  }
}
