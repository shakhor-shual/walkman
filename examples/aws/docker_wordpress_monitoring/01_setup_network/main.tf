provider "aws" {
  region = var.region
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
  name        = "${var.namespace}-security-group"
  description = "Allow SSH and ICMP traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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
    cidr_blocks = ["0.0.0.0/0"]
  }
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

output "security_group_id" {
  value = aws_security_group.my_project_ssh.id
}

output "vpc_id" {
  value = aws_vpc.project_vpc.id
}

output "subnet_id" {
  value = aws_subnet.my_project_subnet.id
}
