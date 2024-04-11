
variable "region" {
  description = "Region for resources !!!default-> Stockholm region"
  default     = "eu-north-1"
}

variable "vpc_name" {
  description = "VPC name"
  default     = "some-vpc"
}

variable "instance_type" {
  description = "EC2 Inastace type"
  default     = "t3.micro"
}

variable "ami" {
  description = "AMI for the instance !!!default-> AmazonLinux 2 Linux AMI in Stockholm, replace with the appropriate one for your region"
  default     = "ami-0f0ec0d37d04440e3"
}

variable "ssh_user" {
  description = "SSH user"
  default     = "walkman"
}

variable "custom_key_public" {
  description = "Path-to-my existing user-defined SSH public key (my use for simplify ssh access to VM) "
  default     = ""
}

variable "auto_key_public" {
  description = "File name/place for auto-generated SSH public key (general ssh access to VM)"
  default     = "../.meta/public.key"
}

variable "auto_key_private" {
  description = "File name/place for auto-generated SSH private key for (general ssh access to VM)"
  default     = "../.meta/private.key"
}



