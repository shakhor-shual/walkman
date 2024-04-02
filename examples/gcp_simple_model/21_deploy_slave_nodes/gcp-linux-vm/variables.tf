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

variable "zone" {
  description = "Google Cloud Platform zone"
  default     = "us-central1-c"
}

variable "network_self_link" {
  description = "Network self link"
}

variable "subnetwork_self_link" {
  description = "Subnetwork self link"
}

variable "group_size" {
  description = "Amount of deployed VMs"
  default     = "1"
}

variable "instance_name" {
  description = "Name of the Compute Engine instance"
  default     = "linux_vm"
}

variable "host" {
  description = "Internal Linux host name of"
  default     = "node"
}
variable "domain" {
  description = "Name of the Compute Engine instance"
  default     = "example.com"
}

variable "machine_type" {
  description = "Machine type for the Compute Engine instance"
  default     = "n1-standard-1"
}

variable "image" {
  description = "Operating system image for the Compute Engine instance"
  default     = "debian-cloud/debian-10"

}

variable "ssh_user" {
  description = "SSH user"
  default     = "shual"
}

variable "ssh_key_public" {
  description = "SSH public keys for accessing the instance"
  default     = "../.meta/public.key"
}

variable "ssh_key_private" {
  description = "SSH private key for accessing the instance"
  default     = "../.meta/private.key"
}

variable "startup_script" {
  description = "StartupScript for additional configuration"
  default     = ""
}

variable "tags" {
  description = "tags for instace"
  default     = []
}

