
provider "azurerm" {
  features {}
}

locals {
  image_version   = "latest"
  image_sku       = "20_04-lts"
  image_offer     = "0001-com-ubuntu-server-focal"
  image_publisher = "Canonical"
  disk_type       = "Standard_LRS"
  disk_size_gb    = 20

  hostname               = "walkman"
  public_ip_allocation   = "Static"
  public_ip_sku          = "Standard"
  vnet_cidr              = "10.0.0.0/16"
  subnet_cidr            = "10.0.200.0/24"
  cloud_init_file_prefix = "metadata/clouds-apt/ubuntu-k8s-bastion_"
  location               = "uksouth"
}

resource "azurerm_resource_group" "walkman_rg" {
  name     = "walkman-resources"
  location = var.location
}

# generate a random prefix
resource "random_string" "walkman_azustring" {
  length  = 16
  special = false
  upper   = false
  numeric = false
}

# Storage account to hold diag data from VMs and Azure Resources
resource "azurerm_storage_account" "walkman_sa" {
  name                     = random_string.walkman_azustring.result
  resource_group_name      = azurerm_resource_group.walkman_rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Route Table for Azure Virtual Network and Server Subnet
resource "azurerm_virtual_network" "walkman_vnet" {
  name                = "master-Vnet"
  resource_group_name = azurerm_resource_group.walkman_rg.name
  location            = var.location
  address_space       = [local.vnet_cidr]
  dns_servers         = ["1.1.1.1", "8.8.8.8"]
}

resource "azurerm_subnet" "walkman_subnet" {
  name                 = "${azurerm_virtual_network.walkman_vnet.name}-kube"
  virtual_network_name = azurerm_virtual_network.walkman_vnet.name
  resource_group_name  = azurerm_resource_group.walkman_rg.name
  address_prefixes     = [local.subnet_cidr]
}

resource "azurerm_route_table" "walkman_rt" {
  name                          = "AzfwRouteTableMasters"
  resource_group_name           = azurerm_resource_group.walkman_rg.name
  location                      = azurerm_resource_group.walkman_rg.location
  disable_bgp_route_propagation = false

  route {
    name           = "AzfwDefaultRouteMasters"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }
}

resource "azurerm_subnet_route_table_association" "walkman_rt_assoc" {
  route_table_id = azurerm_route_table.walkman_rt.id
  subnet_id      = azurerm_subnet.walkman_subnet.id
}

data "azurerm_public_ip" "walkman_ip" {
  resource_group_name = azurerm_resource_group.walkman_rg.name
  name                = azurerm_public_ip.walkman_ip.name
}

# Public IP for Server
resource "azurerm_public_ip" "walkman_ip" {
  resource_group_name = azurerm_resource_group.walkman_rg.name
  location            = azurerm_resource_group.walkman_rg.location
  allocation_method   = local.public_ip_allocation
  sku                 = local.public_ip_sku
  name                = "walkman-IP-${var.namespace}"
}

# NSG for  Server
resource "azurerm_network_security_group" "walkman_nsg" {
  resource_group_name = azurerm_resource_group.walkman_rg.name
  location            = azurerm_resource_group.walkman_rg.location
  name                = "walkman-NSG-${var.namespace}"
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

# Nic for walkman_ Server
resource "azurerm_network_interface" "walkman_nic" {
  resource_group_name = azurerm_resource_group.walkman_rg.name
  location            = azurerm_resource_group.walkman_rg.location
  name                = "walkman-nic-${var.namespace}"

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.walkman_subnet.id
    private_ip_address_allocation = "Dynamic"
    # private_ip_address            = cidrhost(local.subnet_cidr, 250)
    public_ip_address_id = azurerm_public_ip.walkman_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "walkman_nic_assoc" {
  network_interface_id      = azurerm_network_interface.walkman_nic.id
  network_security_group_id = azurerm_network_security_group.walkman_nsg.id
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
  resource_group_name           = azurerm_resource_group.walkman_rg.name
  location                      = azurerm_resource_group.walkman_rg.location
  delete_os_disk_on_termination = true
  name                          = "walkman-${var.namespace}"
  vm_size                       = var.vm_size
  network_interface_ids         = [azurerm_network_interface.walkman_nic.id]
  storage_image_reference {
    publisher = local.image_publisher
    offer     = local.image_offer
    sku       = local.image_sku
    version   = local.image_version
  }
  storage_os_disk {
    name              = "walkman-${var.namespace}-OSDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = local.disk_type
  }
  os_profile {
    computer_name  = "walkman-${var.namespace}"
    admin_username = var.admin_username
    custom_data    = <<-EOF
              #!/bin/bash
              [ -n $(which apt) ] && sudo apt update 
              [ -n $(which apt) ] && sudo apt install -y git mc 
              [ -n $(which yum) ] && sudo yum install -y git mc 
              git clone https://github.com/shakhor-shual/walkman ~/walkman
              chown -R ${var.admin_username}:${var.admin_username} ~/walkman
              mv ~/walkman /home/${var.admin_username}/walkman
              /home/${var.admin_username}/walkman/bin/cw4d.sh ${var.admin_username}
              EOF
  }
  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = local_file.public_key.content
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
    }
  }
  #depends_on = [azurerm_network_interface_security_group_association.walkman_nic_assoc]
}
