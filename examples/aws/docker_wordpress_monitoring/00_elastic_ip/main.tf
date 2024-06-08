provider "aws" {
  region = var.region
}

resource "aws_eip" "elasic_ip" {
  domain = "vpc"
}

output "elastic_ip_id" {
  value = aws_eip.elasic_ip.id
}
