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

# Create EC2 instance - using the deprecated but functional approach
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