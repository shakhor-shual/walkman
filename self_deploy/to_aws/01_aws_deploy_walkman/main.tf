provider "aws" {
  region = var.region
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
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "walkman_subnet" {
  vpc_id     = aws_vpc.project_vpc.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_security_group" "walkman_ssh" {
  vpc_id = aws_vpc.project_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "example_instance" {
  ami             = var.ami
  instance_type   = var.instance_type
  subnet_id       = aws_subnet.walkman_subnet.id
  security_groups = [aws_security_group.walkman_ssh.name]

  # Attaching public key to instance
  key_name = "example_keypair"
  tags = {
    Name = "walkman-instance"
  }

  # Running user data script
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update;sudo apt install -y git mc 
              git clone https://github.com/shakhor-shual/walkman ~/walkman
              chown -R ${var.ssh_user}:${var.ssh_user} ~/walkman
              mv ~/walkman /home/${var.ssh_user}/walkman
              /home/${var.ssh_user}/walkman/bin/cw4d.sh ${var.ssh_user}
              EOF
}

# Outputting the generated public key
output "public_key" {
  value = tls_private_key.example_key.public_key_openssh
}
