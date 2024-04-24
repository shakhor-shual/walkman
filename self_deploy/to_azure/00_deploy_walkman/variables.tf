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

