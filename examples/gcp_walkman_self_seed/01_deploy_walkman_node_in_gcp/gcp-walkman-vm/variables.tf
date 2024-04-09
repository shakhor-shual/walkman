
variable "project_id" {
  description = "project ID"
  default     = "some-roject"
}

variable "region" {
  description = "Region for VPC and subnet"
  default     = "us-central1"
}

variable "zone" {
  description = "Google Cloud Platform zone"
  default     = "us-central1-c"
}

variable "vpc_name" {
  description = "VPC name"
  default     = "some-vpc"
}

variable "machine_type" {
  description = "Machine type for the Compute Engine instance"
  default     = "n1-standard-1"
}

variable "image" {
  description = "Operating system image for the instance !!!Only Ubuntu/Debian dsitros are supported NOW"
  default     = "ubuntu-os-cloud/ubuntu-2004-lts"
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

variable "startup_script" {
  description = "StartupScript for additional configuration"
  default     = ""
}


