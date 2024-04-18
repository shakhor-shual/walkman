/*variable "bastion" {
  description = "Map of project names to configuration."
  type        = map(any)
  default = {
    cloud_init_file_prefix = "metadata/clouds-apt/ubuntu-k8s-bastion_"
    image_version          = "latest",
    image_sku              = "20_04-lts-gen2",
    image_offer            = "0001-com-ubuntu-server-focal",
    image_publisher        = "Canonical",
    disk_type              = "Standard_LRS",
    disk_size_gb           = 30,
    vm_size                = "Standard_B1ms",
    location               = "uksouth",
    hostname               = "bastion",
    vnet_addr              = "10.0.0.0/16",
    subnet_addr            = "10.0.200.0/24",
    peer_vnet_addr         = "10.1.0.0/16"
  }
}
*/

variable "location" {
  default     = "ukwest"
  description = "The Azure location where all resources in this example should be created"
}

variable "namespace" {
  default = "one"
}

variable "vm_size" {
  description = "The Azure size (.i.e this a type of VM in terms of Azure)"
  default     = "Standard_B1ms"
}

variable "admin_username" {
  default = "ubuntu"
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

