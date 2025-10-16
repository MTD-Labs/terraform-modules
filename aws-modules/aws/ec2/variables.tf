variable "region" {
  type    = string
  default = "me-south-1"
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

variable "grafana_enabled" {
  type        = bool
  description = "Enable Grafana"
  default     = true
}

variable "grafana_domain" {
  type        = string
  description = "Grafana Domain Grafana"
  default     = ""
}

variable "ecr_user_id" {
  type    = string
  default = ""
}
