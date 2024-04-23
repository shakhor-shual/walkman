
provider "azurerm" {
  features {}
}

locals {
  hostname             = "walkman"
  public_ip_allocation = "Static"
  public_ip_sku        = "Standard"

}

resource "azurerm_resource_group" "my_rg" {
  name     = "${var.namespace}-resources"
  location = var.location
}

# generate a random prefix
resource "random_string" "my_azustring" {
  length  = 16
  special = false
  upper   = false
  numeric = false
}

# Storage account to hold diag data from VMs and Azure Resources
resource "azurerm_storage_account" "my_sa" {
  name                     = random_string.my_azustring.result
  resource_group_name      = azurerm_resource_group.my_rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Route Table for Azure Virtual Network and Server Subnet
resource "azurerm_virtual_network" "my_vnet" {
  name                = "master-Vnet"
  resource_group_name = azurerm_resource_group.my_rg.name
  location            = var.location
  address_space       = var.vnet_cidr
  dns_servers         = ["1.1.1.1", "8.8.8.8"]
}

resource "azurerm_subnet" "my_subnet" {
  name                 = "${azurerm_virtual_network.my_vnet.name}-one"
  virtual_network_name = azurerm_virtual_network.my_vnet.name
  resource_group_name  = azurerm_resource_group.my_rg.name
  address_prefixes     = var.subnet_cidr
}

resource "azurerm_route_table" "my_rt" {
  name                          = "AzfwRouteTableMasters"
  resource_group_name           = azurerm_resource_group.my_rg.name
  location                      = azurerm_resource_group.my_rg.location
  disable_bgp_route_propagation = false

  route {
    name           = "AzfwDefaultRouteMasters"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }
}

resource "azurerm_subnet_route_table_association" "my_rt_assoc" {
  route_table_id = azurerm_route_table.my_rt.id
  subnet_id      = azurerm_subnet.my_subnet.id
}

# Public IP for Server
resource "azurerm_public_ip" "my_ip" {
  resource_group_name = azurerm_resource_group.my_rg.name
  location            = azurerm_resource_group.my_rg.location
  allocation_method   = local.public_ip_allocation
  sku                 = local.public_ip_sku
  name                = "vm-IP-${var.namespace}"
}

# NSG for  Server
resource "azurerm_network_security_group" "my_nsg" {
  resource_group_name = azurerm_resource_group.my_rg.name
  location            = azurerm_resource_group.my_rg.location
  name                = "vm-NSG-${var.namespace}"
  security_rule {
    name                       = "SSH"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Nic for my_ Server
resource "azurerm_network_interface" "my_nic" {
  resource_group_name = azurerm_resource_group.my_rg.name
  location            = azurerm_resource_group.my_rg.location
  name                = "vm-nic-${var.namespace}"

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.my_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "my_nic_assoc" {
  network_interface_id      = azurerm_network_interface.my_nic.id
  network_security_group_id = azurerm_network_security_group.my_nsg.id
}

resource "tls_private_key" "my_vm_access" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "public_key" {
  filename        = var.auto_key_public
  content         = trimspace(tls_private_key.my_vm_access.public_key_openssh)
  file_permission = "0400"
}

resource "local_sensitive_file" "private_key" {
  filename = var.auto_key_private
  # IMPORTANT: Newline is required at end of open SSH private key file
  content         = tls_private_key.my_vm_access.private_key_openssh
  file_permission = "0400"
}

# Walkman VM
resource "azurerm_virtual_machine" "walkman" {
  resource_group_name           = azurerm_resource_group.my_rg.name
  location                      = azurerm_resource_group.my_rg.location
  delete_os_disk_on_termination = true
  name                          = "vm-${var.namespace}"
  vm_size                       = var.vm_size
  network_interface_ids         = [azurerm_network_interface.my_nic.id]
  storage_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }
  storage_os_disk {
    name              = "vm-${var.namespace}-OSDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = var.disk_type
    disk_size_gb      = var.disk_size_gb
  }
  os_profile {
    computer_name  = "vm-${var.namespace}"
    admin_username = var.admin_username
    custom_data    = fileexists(var.custom_data_file) ? file(var.custom_data_file) : ""
  }
  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = local_file.public_key.content
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }
}

output "user_info_note" {
  value = "----- run SSH command from wolkman_ssh for instatnt access to VM  ----------"
}

output "wolkman_ssh" {
  value = "ssh -oStrictHostKeyChecking=no -oUserKnownHostsFile=/dev/null -i ${abspath(var.auto_key_private)} ${var.admin_username}@${azurerm_public_ip.my_ip.ip_address}"
}

output "ssh_user" {
  value = var.admin_username
}

output "ssh_user_key" {
  value = abspath(var.auto_key_private)
}

output "access_ip" {
  value = azurerm_public_ip.my_ip.ip_address
}
