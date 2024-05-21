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
resource "tls_private_key" "walkman_vm_access" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "public_key" {
  filename        = var.auto_key_public
  content         = trimspace(tls_private_key.walkman_vm_access.public_key_openssh)
  file_permission = "0400"
}

resource "local_sensitive_file" "private_key" {
  filename = var.auto_key_private
  # IMPORTANT: Newline is required at end of open SSH private key file
  content         = tls_private_key.walkman_vm_access.private_key_openssh
  file_permission = "0400"
}

resource "aws_vpc" "project_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "walkman_subnet" {
  vpc_id     = aws_vpc.project_vpc.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_security_group" "walkman_ssh" {
  vpc_id      = aws_vpc.project_vpc.id
  name        = "walkman-security-group"
  description = "Allow SSH and ICMP traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Разрешить доступ в любую сеть
  }
}

resource "aws_key_pair" "walkman_key_pair" {
  key_name   = "walkman-key-pair"
  public_key = local_file.public_key.content
}


resource "aws_internet_gateway" "walkman" {
  vpc_id = aws_vpc.project_vpc.id
}

resource "aws_route_table" "walkman" {
  vpc_id = aws_vpc.project_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.walkman.id
  }
}

resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.walkman_subnet.id
  route_table_id = aws_route_table.walkman.id
}

resource "aws_instance" "walkman_instance" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.walkman_subnet.id
  vpc_security_group_ids = [aws_security_group.walkman_ssh.id]

  # Attaching public key to instance
  key_name = aws_key_pair.walkman_key_pair.key_name
  tags = {
    Name = "walkman-instance"
  }

  user_data = <<-EOF
              #!/bin/bash
              which yum 2>/dev/null && sudo yum install -y git 
              which dnf 2>/dev/null && sudo dnf install -y git
              which apt 2>/dev/null && sudo apt update
              which apt 2>/dev/null && sudo apt install -y git
              git clone https://github.com/shakhor-shual/walkman ~/walkman
              chown -R ${local.ssh_user}:${local.ssh_user} ~/walkman
              mv ~/walkman /home/${local.ssh_user}/walkman
              /home/${local.ssh_user}/walkman/bin/cw4d.sh ${local.ssh_user}
              EOF

  root_block_device {
    volume_size = var.volume_size
  }

  associate_public_ip_address = true
}

output "user_info_note" {
  value = "<<<<<<<< run SSH command from walkman_ssh for instatnt access to VM  >>>>>>>>"
}

output "walkman_ssh" {
  value = "ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -i ${abspath(var.auto_key_private)} ${local.ssh_user}@${aws_instance.walkman_instance.public_ip}"
}

output "ssh_user" {
  value = local.ssh_user
}

output "ssh_user_key" {
  value = abspath(var.auto_key_private)
}

output "access_ip" {
  value = aws_instance.walkman_instance.public_ip
}
