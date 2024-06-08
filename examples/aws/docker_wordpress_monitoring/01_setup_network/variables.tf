
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


