provider "azurerm" {
  version = "~>2.0"
  features {}
}

provider "tls" {
  version = "~>2.1"
}

terraform {
  backend "azurerm" {
    resource_group_name   = "az-tf-tut-infra-rg"
    storage_account_name  = "aztftutinfra"
    container_name        = "infra"
    key                   = "terraform.tfstate"
  }
}

resource "azurerm_resource_group" "rg" {
  name     = "az-tf-tut-rg"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "az-tf-tut-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = {
    environment = "Terraform Azure Demo"
  }
}

resource "azurerm_subnet" "snet" {
  name                 = "az-tf-tut-snet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}


resource "azurerm_public_ip" "public_ip" {
  name                = "az-tf-tut-public-ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"

  tags = {
    environment = "Terraform Azure Demo"
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = "az-tf-tut-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Terraform Azure Demo"
  }
}

resource "azurerm_network_interface" "nic" {
  name                = "az-tf-tut-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "az-tf-tut-nic-config"
    subnet_id                     = azurerm_subnet.snet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }

  tags = {
    environment = "Terraform Azure Demo"
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nic_nsg_association" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_storage_account" "storage_account" {
  name                     = "aztftutstorage"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_replication_type = "LRS"
  account_tier             = "Standard"

  tags = {
    environment = "Terraform Azure Demo"
  }
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

output "tls_private_key" { value = "tls_private_key.ssh.private_key_pem" }

resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "az-tf-tut-vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic.id,]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04.0-LTS"
    version   = "latest"
  }

  computer_name                   = "myvm"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.storage_account.primary_blob_endpoint
  }

  tags = {
    environment = "Terraform Demo"
  }
}