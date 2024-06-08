provider "aws" {
  region = var.region
}

locals {
  debian_ami   = "ami-0506d6d51f1916a96" # Debian 12
  ubuntu20_ami = "ami-010b74bc1a8b29122" #Ubuntu 20-04
  ubuntu22_ami = "ami-0914547665e6a707c" #Ubuntu 22-04
  ssh_user     = var.ami == local.debian_ami ? "admin" : var.ami == local.ubuntu20_ami || var.ami == local.ubuntu22_ami ? "ubuntu" : "ec2-user"
}

# Generating SSH key pair
resource "tls_private_key" "my_vm_access" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "public_key" {
  filename        = var.auto_key_public
  content         = trimspace(tls_private_key.my_vm_access.public_key_openssh)
  file_permission = "0400"
}

resource "local_sensitive_file" "private_key" {
  filename = var.auto_key_private
  # IMPORTANT: Newline is required at end of open SSH private key file
  content         = tls_private_key.my_vm_access.private_key_openssh
  file_permission = "0400"
}

resource "aws_key_pair" "my_key_pair" {
  key_name   = "${var.namespace}-key-pair"
  public_key = local_file.public_key.content
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.my_project_instance.id
  allocation_id = var.elastic_ip_id
}

resource "aws_instance" "my_project_instance" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id #aws_subnet.my_project_subnet.id
  vpc_security_group_ids = [var.security_group_id]

  # Attaching public key to instance
  key_name = aws_key_pair.my_key_pair.key_name
  tags = {
    Name = "my_project-instance"
  }

  user_data = fileexists(var.user_data_file) ? file(var.user_data_file) : ""

  root_block_device {
    volume_size = var.volume_size
  }

  #associate_public_ip_address = true
}

output "user_info_note" {
  value = "<<<<<<<<<<< run SSH command from user_project_ssh for instatnt access to VM  >>>>>>>>>"
}

output "user_project_ssh" {
  value = "ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -i ${abspath(var.auto_key_private)} ${local.ssh_user}@${aws_instance.my_project_instance.public_ip}"
}

output "walkman_install" {
  value = "cw4d.sh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -i ${abspath(var.auto_key_private)} ${local.ssh_user}@${aws_instance.my_project_instance.public_ip}"
}

output "ssh_user" {
  value = local.ssh_user
}

output "ssh_user_key" {
  value = abspath(var.auto_key_private)
}

output "access_ip" {
  value = aws_instance.my_project_instance.public_ip
}
