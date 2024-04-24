provider "aws" {
  region = var.region
}

locals {
  ssh_user = "ec2-user"
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

resource "aws_vpc" "project_vpc" {
  cidr_block = var.vpc_cidr_block
}

resource "aws_subnet" "my_project_subnet" {
  vpc_id     = aws_vpc.project_vpc.id
  cidr_block = var.subnet_cidr_block
}

resource "aws_security_group" "my_project_ssh" {
  vpc_id      = aws_vpc.project_vpc.id
  name        = "$(var.namespace)-security-group"
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

resource "aws_key_pair" "my_key_pair" {
  key_name   = "$(var.namespace)-key-pair"
  public_key = local_file.public_key.content
}


resource "aws_internet_gateway" "my_project_gw" {
  vpc_id = aws_vpc.project_vpc.id
}

resource "aws_route_table" "my_project_rt" {
  vpc_id = aws_vpc.project_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_project_gw.id
  }
}

resource "aws_route_table_association" "subnet-association" {
  subnet_id      = aws_subnet.my_project_subnet.id
  route_table_id = aws_route_table.my_project_rt.id
}

resource "aws_instance" "my_project_instance" {
  ami             = var.ami
  instance_type   = var.instance_type
  subnet_id       = aws_subnet.my_project_subnet.id
  security_groups = [aws_security_group.my_project_ssh.id]

  # Attaching public key to instance
  key_name = "$(var.namespace)-key-pair"
  tags = {
    Name = "my_project-instance"
  }

  user_data = fileexists(var.user_data_file) ? file(var.user_data_file) : ""

  root_block_device {
    volume_size = var.volume_size
  }

  associate_public_ip_address = true
}

output "user_info_note" {
  value = "<<<<<<<<<<< run SSH command from user_project_ssh for instatnt access to VM  >>>>>>>>>"
}

output "user_project_ssh" {
  value = "ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -i ${abspath(var.auto_key_private)} ${local.ssh_user}@${aws_instance.my_project_instance.public_ip}"
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
