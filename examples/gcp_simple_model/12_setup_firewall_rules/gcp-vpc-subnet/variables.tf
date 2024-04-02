# ====  WW4 specific variables DO NOT CHANGE THEM =====
variable "album_meta_store" {
  description = "Path to access files store"
  default     = "../../.meta"
}
#======================================================

variable "namespace" {
  description = "GCP credentials file name"
  default     = "default"
}

variable "credentials_file" {
  description = "GCP credentials file name"
  default     = "/home/ubuntu/WALKMAN/ALBUMS/WF_1/.meta/gcp.json"
}

variable "project_id" {
  description = "project ID"
  default     = "some-roject"
}

variable "region" {
  description = "Region for VPC and subnet"
  default     = "us-central1"
}

variable "network" {
  description = "VPC name or self_link"
  default     = "some-vpc"
}

variable "tag_allow_web" {
  description = "TAG for web access enable"
  default     = "allow-web"
}

variable "tag_allow_ssh" {
  description = "TAG for ssh access enable"
  default     = "allow-ssh"
}


