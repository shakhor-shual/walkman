variable "credentials_file" {
  description = "GCP credentials file name"
  default     = "gcp.json"
}

variable "project_id" {
  description = "project ID"
  default     = "some-roject"
}

variable "project_tenant" {
  description = "tenant subset in project"
  default     = "some-tenant"
}

variable "region" {
  description = "Region for VPC and subnet"
  default     = "us-central1"
}

variable "vpc_name" {
  description = "VPC name"
  default     = "some-vpc"
}

variable "subnet_name" {
  description = "Subnetwork name"
  default     = "some-subnet"
}

variable "subnet_cidr" {
  description = "CIDR range"
  default     = "10.0.0.0/24"
}

