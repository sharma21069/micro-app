

provider "azurerm" {
   subscription_id = "${var.subscriptionid}"
   client_id       = "${var.clientid}"
   client_secret   = "${var.clientsecret}"
   tenant_id       = "${var.tenantid}"
   features {}
}

locals {
  project-location       = "${var.location}"
  project-resource-group = "project-vnet-rg"
  prefix-project         = "project"
}

resource "azurerm_resource_group" "project-vnet-rg" {
  name     = local.project-resource-group
  location = "${var.location}"
}

resource "azurerm_virtual_network" "project-vnet" {
  name                = "project-vnet"
  location            = azurerm_resource_group.project-vnet-rg.location
  resource_group_name = azurerm_resource_group.project-vnet-rg.name
  address_space       = ["10.2.0.0/16"]

  tags = {
    environment = local.prefix-project
  }
}

resource "azurerm_subnet" "project-bastion" {
  name                 = "bastion"
  resource_group_name  = azurerm_resource_group.project-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.project-vnet.name
  address_prefix       = "10.2.1.0/24"
}

resource "azurerm_subnet" "project-fe" {
  name                 = "fe"
  resource_group_name  = azurerm_resource_group.project-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.project-vnet.name
  address_prefix       = "10.2.2.0/24"
}

resource "azurerm_subnet" "project-be" {
  name                 = "be"
  resource_group_name  = azurerm_resource_group.project-vnet-rg.name
  virtual_network_name = azurerm_virtual_network.project-vnet.name
  address_prefix       = "10.2.3.0/24"
}



##################sg #################


resource "azurerm_network_security_group" "bastion-sg" {
  name                = "bastionSecurityGroup"
  location            = azurerm_resource_group.project-vnet-rg.location
  resource_group_name = azurerm_resource_group.project-vnet-rg.name

  security_rule {
    name                       = "ssh-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "ssh-out"
    priority                   = 101
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "22"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "10.2.0.0/16"
  }
}


  resource "azurerm_network_security_group" "frontend-sg" {
    name                = "frontSecurityGroup"
    location            = azurerm_resource_group.project-vnet-rg.location
    resource_group_name = azurerm_resource_group.project-vnet-rg.name

    security_rule {
      name                       = "sshbastion"
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "10.2.1.0/24"
      destination_address_prefix = "*"
    }

    security_rule {
      name                       = "tcpinternet"
      priority                   = 101
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "Internet"
      destination_address_prefix = "*"
    }

    security_rule {
      name                       = "Appconnection"
      priority                   = 102
      direction                  = "Outbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "10.2.3.0/24"
    }
}

    resource "azurerm_network_security_group" "backend-sg" {
      name                = "backendSecurityGroup"
      location            = azurerm_resource_group.project-vnet-rg.location
      resource_group_name = azurerm_resource_group.project-vnet-rg.name

      security_rule {
        name                       = "sshbastion"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "10.2.1.0/24"
        destination_address_prefix = "*"
      }
      security_rule {
        name                       = "tcpfe"
        priority                   = 101
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "10.2.2.0/24"
        destination_address_prefix = "*"
      }

      security_rule {
        name                       = "tcpfedeny"
        priority                   = 102
        direction                  = "Outbound"
        access                     = "Deny"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "10.2.2.0/24"
      }
}

resource "azurerm_subnet_network_security_group_association" "nsg-ba" {
  subnet_id                 = azurerm_subnet.project-bastion.id
  network_security_group_id = azurerm_network_security_group.bastion-sg.id
}


resource "azurerm_subnet_network_security_group_association" "nsg-fe" {
  subnet_id                 = azurerm_subnet.project-fe.id
  network_security_group_id = azurerm_network_security_group.frontend-sg.id
}

resource "azurerm_subnet_network_security_group_association" "nsg-be" {
  subnet_id                 = azurerm_subnet.project-be.id
  network_security_group_id = azurerm_network_security_group.backend-sg.id
  }



########################bastion vm###################




resource "azurerm_public_ip" "ba" {
  name                = "ba-pip"
  resource_group_name = azurerm_resource_group.project-vnet-rg.name
  location            = azurerm_resource_group.project-vnet-rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "ba" {
  name                = "ba-nic"
  resource_group_name = azurerm_resource_group.project-vnet-rg.name
  location            = azurerm_resource_group.project-vnet-rg.location

  ip_configuration {
    name                          = "internal-ba"
    subnet_id                     = azurerm_subnet.project-bastion.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ba.id
  }
}

resource "azurerm_linux_virtual_machine" "ba-vm" {
  name                            = "ba-vm"
  resource_group_name             = azurerm_resource_group.project-vnet-rg.name
  location                        = azurerm_resource_group.project-vnet-rg.location
  size                            = "Standard_F2"
  admin_username                  = "adminuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.ba.id,
  ]

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
  #depends_on = [azurerm_subnet_network_security_group_association.nsg-ba]
}



####################### frontend VM###################333

resource "azurerm_public_ip" "fe" {
  name                = "fe-pip"
  resource_group_name = azurerm_resource_group.project-vnet-rg.name
  location            = azurerm_resource_group.project-vnet-rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "fe" {
  name                = "fe-nic"
  resource_group_name = azurerm_resource_group.project-vnet-rg.name
  location            = azurerm_resource_group.project-vnet-rg.location

  ip_configuration {
    name                          = "internal-fe"
    subnet_id                     = azurerm_subnet.project-fe.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.fe.id
  }
}

resource "azurerm_linux_virtual_machine" "fe-vm" {
  name                            = "fe-vm"
  resource_group_name             = azurerm_resource_group.project-vnet-rg.name
  location                        = azurerm_resource_group.project-vnet-rg.location
  size                            = "Standard_F2"
  admin_username                  = "adminuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.fe.id,
  ]

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get install curl",
      "sudo apt-get install httpd",
    ]

    connection {
      host     = self.private_ip_address
      user     = self.admin_username
      password = self.admin_password
      bastion_host = azurerm_public_ip.ba.ip_address
      bastion_port = 22
      bastion_user = "adminuser"
      bastion_password = "P@ssw0rd1234!"
    }

  #  depends_on = [azurerm_linux_virtual_machine.ba-vm]
  }
}


################ vm backend #



resource "azurerm_public_ip" "be" {
  name                = "be-pip"
  resource_group_name = azurerm_resource_group.project-vnet-rg.name
  location            = azurerm_resource_group.project-vnet-rg.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "be" {
  name                = "be-nic"
  resource_group_name = azurerm_resource_group.project-vnet-rg.name
  location            = azurerm_resource_group.project-vnet-rg.location

  ip_configuration {
    name                          = "internal-be"
    subnet_id                     = azurerm_subnet.project-be.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.be.id
  }
}

resource "azurerm_linux_virtual_machine" "be-vm" {
  name                            = "be-vm"
  resource_group_name             = azurerm_resource_group.project-vnet-rg.name
  location                        = azurerm_resource_group.project-vnet-rg.location
  size                            = "Standard_F2"
  admin_username                  = "adminuser"
  admin_password                  = "P@ssw0rd1234!"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.be.id,
  ]

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get install curl httpd",
    ]

    connection {
      host     = self.private_ip_address
      user     = self.admin_username
      password = self.admin_password
      bastion_host = azurerm_public_ip.ba.ip_address
      bastion_port = 22
      bastion_user = "adminuser"
      bastion_password = "P@ssw0rd1234!"
    }
    #depends_on = [azurerm_linux_virtual_machine.ba-vm]
  }
}
