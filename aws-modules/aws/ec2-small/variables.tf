variable "region" {
  type    = string
  default = "us-east-1"
}

variable "env" {
  type = string
}

variable "name" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = null
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "private_subnet_id" {
  type    = string
  default = ""
}

variable "public_subnet_id" {
  type    = string
  default = ""
}

variable "enable_public_access" {
  type        = bool
  description = "Enable external access"
  default     = true
}

variable "ami_filter" {
  description = "List of maps used to create the AMI filter for the used AMI."
  type        = map(list(string))

  default = {
    name                = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    virtualization-type = ["hvm"]
  }
}

variable "ami_owners" {
  description = "The list of owners used to select the AMI of used instances."
  type        = list(string)
  default     = ["099720109477"] # Canonical
}

variable "ami" {
  type        = string
  description = "AMI to use for the instance. Setting this will ignore `ami_filter` and `ami_owners`."
  default     = null
}

variable "instance_type" {
  type        = string
  description = "Instance type for the created machine"
  default     = "t3.micro"
}

variable "allowed_tcp_ports" {
  type        = list(number)
  description = "Default set of TCP ports to allow in Security Group for ingress"
  default     = [22, 80, 443]
}

variable "allowed_udp_ports" {
  type        = list(number)
  description = "Default set of UDP ports to allow in Security Group for ingress"
  default     = []
}

variable "allowed_cidr_blocks" {
  type        = list(string)
  description = "Source IP CIDRs to allow in Security Group for ingress"
  default     = ["0.0.0.0/0"]
}

variable "ssh_authorized_keys_secret" {
  description = "Parameter store secret key with SSH authorized keys file content"
  type        = string
}

variable "key_name" {
  type    = string
  default = null
}

variable "ec2_root_volume_size" {
  type    = number
  default = 10
}

variable "ec2_root_volume_type" {
  type    = string
  default = "gp2"
}

variable "additional_disk" {
  type    = bool
  default = false
}

variable "additional_disk_size" {
  type    = number
  default = null
}

variable "additional_disk_type" {
  type    = string
  default = "gp2"
}

variable "private_key_path" {
  type    = string
  default = ""
}

variable "ecr_user_id" {
  type    = string
  default = ""
}

variable "domain_name" {
  type    = string
  default = ""
}

variable "ubuntu_ami_name_pattern" {
  description = "The name pattern for Ubuntu AMI"
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu-noble-24.04-arm64-server-*"
}

variable "instance_arch" {
  description = "The arch of EC2 Instance"
  type        = string
  default     = "arm64"
}

variable "services_list" {
  type    = list(string)
  default = ["service1", "service2"]
}

variable "ami_id" {
  type    = string
  default = "ami-03e40101f6ac56b76"
}
