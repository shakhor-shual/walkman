variable "location" {
  default     = "ukwest"
  description = "The Azure location where all resources in this example should be created"
}

variable "namespace" {
  default = "one"
}

variable "vnet_cidr" {
  description = "Vnet CIDR"
  default     = ["10.0.0.0/16"]
}
variable "subnet_cidr" {
  description = "Subnet CIDR"
  default     = ["10.0.200.0/24"]
}

variable "vm_size" {
  description = "The Azure size (.i.e this a type of VM in terms of Azure)"
  default     = "Standard_B1ms"
}

variable "disk_size_gb" {
  description = "OS Disk size"
  default     = 30
}

variable "disk_type" {
  description = "OS Disk type"
  default     = "Standard_LRS"
}

variable "image_publisher" {
  description = "OS Image Publisher"
  default     = "Canonical"
}

variable "image_version" {
  description = "OS Image version"
  default     = "latest"
}
variable "image_offer" {
  description = "OS Image offer"
  default     = "0001-com-ubuntu-server-focal"
}
variable "image_sku" {
  description = "OS Image SKU"
  default     = "20_04-lts-gen2"
}

variable "admin_username" {
  description = "OS admin user name"
  default     = "ubuntu"
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

variable "custom_data_file" {
  description = "File with user data script"
  default     = "../.meta/custom_data.sh"
}
