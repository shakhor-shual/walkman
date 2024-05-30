
variable "region" {
  description = "Region for resources !!!default-> Stockholm region"
  default     = "eu-north-1"
}

variable "namespace" {
  description = "Namespace for"
  default     = "my-test"
}

variable "vpc_cidr_block" {
  description = "VPC cidr"
  default     = "10.0.0.0/16"
}

variable "subnet_cidr_block" {
  description = "Subnet cidr"
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "EC2 Inastace type"
  default     = "t3.micro"
}

variable "volume_size" {
  description = "OS Disk size"
  default     = 25
}

variable "ami" {
  description = "AMI for the instance !!!default-> AmazonLinux 2 Linux AMI in Stockholm,  replace with the appropriate one for your region"
  default     = "ami-0f0ec0d37d04440e3"
}

variable "custom_key_public" {
  description = "Path-to-my existing user-defined SSH public key (my use for simplify ssh access to VM ) "
  default     = ""
}

variable "auto_key_public" {
  description = "File name/place for auto-generated SSH public key ( general ssh access to VM )"
  default     = "../.meta/public.key"
}

variable "auto_key_private" {
  description = "File name/place for auto-generated SSH private key for (general ssh access to VM)"
  default     = "../.meta/private.key"
}

variable "user_data_file" {
  description = "File with user data script"
  default     = "../.meta/user_data.sh"
}

