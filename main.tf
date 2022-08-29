terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "2.93.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.azure_subscription_description["subscription_id"]
  client_id       = var.azure_subscription_description["client_id"]
  client_secret   = var.azure_subscription_description["client_secret"]
  tenant_id       = var.azure_subscription_description["tenant_id"]
  features {}
}

resource "azurerm_resource_group" "app"{
  name="app"
  location="West US 3"
}

resource "azurerm_virtual_network" "app_network" {
  name                = "app-network"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  address_space       = ["10.0.0.0/16"]  
  depends_on = [
    azurerm_resource_group.app
  ]
}

resource "azurerm_subnet" "SubnetA" {
  name                 = "SubnetA"
  resource_group_name  = azurerm_resource_group.app.name
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on = [
    azurerm_virtual_network.app_network
  ]
}

resource "azurerm_public_ip" "load_ip" {
  name                = "load-ip"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  allocation_method   = "Static"
  domain_name_label = "devopstestiissite"
  sku="Standard"
}

resource "azurerm_public_ip" "test" {
  count = 2
  name                = "publicIPforVM${count.index}"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  domain_name_label = "test09890vm${count.index}"
  allocation_method   = "Static"
  sku="Standard"
  zones = [count.index + 1]
}

resource "azurerm_dns_zone" "example" {
  name                = "westus3.cloudapp.azure.com"
  resource_group_name = azurerm_resource_group.app.name
}

resource "azurerm_dns_a_record" "example" {
  count = 2
  name                = "dnsforvm${count.index}"
  zone_name           = azurerm_dns_zone.example.name
  resource_group_name = azurerm_resource_group.app.name
  ttl                 = 300
target_resource_id  = azurerm_public_ip.test[count.index].id
}


resource "azurerm_dns_a_record" "examplelb" {
  name                = "dnsforlb"
  zone_name           = azurerm_dns_zone.example.name
  resource_group_name = azurerm_resource_group.app.name
  ttl                 = 300
target_resource_id  = azurerm_public_ip.load_ip.id
}

resource "azurerm_lb" "app_balancer" {
  name                = "app-balancer"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name
  sku="Standard"
  sku_tier = "Regional"
  frontend_ip_configuration {
    name                 = "frontend-ip"
    public_ip_address_id = azurerm_public_ip.load_ip.id
  }

  depends_on=[
    azurerm_public_ip.load_ip
  ]
}

resource "azurerm_lb_backend_address_pool" "vmpool" {
  loadbalancer_id = azurerm_lb.app_balancer.id
  name            = "vmspool"
  depends_on=[
    azurerm_lb.app_balancer
  ]
}

resource "azurerm_lb_probe" "ProbeA" {
  resource_group_name = azurerm_resource_group.app.name
  loadbalancer_id     = azurerm_lb.app_balancer.id
  name                = "probeA"
  port                = 80
  protocol            =  "Tcp"
  depends_on=[
    azurerm_lb.app_balancer
  ]
}

resource "azurerm_lb_rule" "RuleA" {
  resource_group_name            = azurerm_resource_group.app.name
  loadbalancer_id                = azurerm_lb.app_balancer.id
  name                           = "RuleA"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_ids = [ azurerm_lb_backend_address_pool.vmpool.id ]
}

resource "azurerm_network_interface" "test" {
   count               = 2
   name                = "acctni${count.index}"
   location            = azurerm_resource_group.app.location
   resource_group_name = azurerm_resource_group.app.name
   dns_servers         = ["8.8.8.8","1.1.1.1"]
   ip_configuration {
     name                          = "testConfiguration"
     subnet_id                     = azurerm_subnet.SubnetA.id
     private_ip_address_allocation = "dynamic"
     public_ip_address_id = azurerm_public_ip.test[count.index].id
   }
 }

resource "azurerm_network_interface_backend_address_pool_association" "example" {
  count = 2
  network_interface_id    = azurerm_network_interface.test[count.index].id
  ip_configuration_name   = "testConfiguration"
  backend_address_pool_id = azurerm_lb_backend_address_pool.vmpool.id
}

resource "azurerm_virtual_machine" "test" {
   count                 = 2
   name                  = "acctvm${count.index}"
   location              = azurerm_resource_group.app.location
   resource_group_name   = azurerm_resource_group.app.name
   network_interface_ids = [element(azurerm_network_interface.test.*.id, count.index)]
   vm_size               = "Standard_DS1_v2"
   zones = [count.index + 1]

   storage_image_reference {
     publisher = "MicrosoftWindowsServer"
     offer     = "WindowsServer"
     sku       = "2019-Datacenter"
     version   = "latest"
   }

   storage_os_disk {
     name              = "myoosdisk${count.index}"
     caching           = "ReadWrite"
     create_option     = "FromImage"
     managed_disk_type = "Standard_LRS"
   }

   os_profile {
     computer_name  = var.user["computer_name"]
     admin_username = var.user["admin_username"]
     admin_password = var.user["admin_password"]
   }

   os_profile_windows_config { 
    provision_vm_agent = true
}
 }

resource "azurerm_network_security_group" "app_nsg" {
  name                = "app-nsg"
  location            = azurerm_resource_group.app.location
  resource_group_name = azurerm_resource_group.app.name

  security_rule {
    name                       = "Allow_HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.SubnetA.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
  depends_on = [
    azurerm_network_security_group.app_nsg
  ]
}
