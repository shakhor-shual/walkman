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
  vpc_id      = aws_vpc.project_vpc.id
  name        = "my-security-group"
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

  # Разрешение исходящего трафика
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Разрешить доступ в любую сеть
  }
}

resource "aws_key_pair" "my_key_pair" {
  key_name   = "my-key-pair"
  public_key = local_file.public_key.content # Путь к вашему публичному ключу
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
  ami             = var.ami
  instance_type   = var.instance_type
  subnet_id       = aws_subnet.walkman_subnet.id
  security_groups = [aws_security_group.walkman_ssh.id]

  # Attaching public key to instance
  key_name = "my-key-pair"
  tags = {
    Name = "walkman-instance"
  }

  # Running user data script
  user_data = <<-EOF
              #!/bin/bash
              sudo yum install -y git mc 
              git clone https://github.com/shakhor-shual/walkman ~/walkman
              chown -R ${var.ssh_user}:${var.ssh_user} ~/walkman
              mv ~/walkman /home/${var.ssh_user}/walkman
              /home/${var.ssh_user}/walkman/bin/cw4d.sh ${var.ssh_user}
              EOF

  root_block_device {
    volume_size = 25
  }

  associate_public_ip_address = true
}

