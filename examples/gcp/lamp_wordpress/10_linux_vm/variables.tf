
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

variable "host" {
  default = "one"
}

variable "vpc_name" {
  description = "VPC name"
  default     = "some-vpc"
}

variable "machine_type" {
  description = "Machine type for the Compute Engine instance"
  default     = "n2-standard-2"
}

variable "boot_disk_size" {
  description = "Operating system disk size GB"
  default     = 50
}

variable "boot_disk_type" {
  description = "Operating system disk type"
  default     = "pd-balanced"
}

variable "boot_image" {
  description = "Operating system image for the instance "
  default     = "ubuntu-os-cloud/ubuntu-2004-lts"
}

variable "ssh_user" {
  description = "SSH user"
  default     = "admin"
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

variable "startup_script_file" {
  description = "File with user startup script"
  default     = "../.meta/user_data.sh"
}

