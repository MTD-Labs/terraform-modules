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

### Commented block below generates a new key file

# resource "tls_private_key" "private_key" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }

# module "key_pair" {
#   source  = "terraform-aws-modules/key-pair/aws"
#   version = "2.0.2"

#   key_name   = local.name
#   public_key = trimspace(tls_private_key.private_key.public_key_openssh)

#   tags = local.tags
# }

# resource "local_file" "private_key" {
#   content         = tls_private_key.private_key.private_key_pem
#   filename        = "${path.module}/../../../../../${local.name}.pem"
#   file_permission = "0600"
# }

data "aws_ssm_parameter" "ssh_authorized_keys" {
  name = var.ssh_authorized_keys_secret
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

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ami.id
  ebs_optimized = true
  instance_type = var.instance_type
  # key_name          = module.key_pair.key_pair_name
  availability_zone = "${var.region}a"

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

  tags = local.tags

  volume_tags = local.tags

  lifecycle {
    ignore_changes = [ami]
  }

}
