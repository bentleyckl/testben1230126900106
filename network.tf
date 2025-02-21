# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = "Southeast Asia"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.env_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.0.0.0/16"]
}

# Public Subnet
resource "azurerm_subnet" "public" {
  name                 = "public-subnet-${var.env_name}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Private Subnet
resource "azurerm_subnet" "private" {
  name                 = "private-subnet-${var.env_name}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.env_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "Allow-ALL-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-All-Outbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with the Public Subnet
resource "azurerm_subnet_network_security_group_association" "public_nsg_assoc" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Public IP for Load Balancer
resource "azurerm_public_ip" "lb_ip" {
  name                = "lb-ip-${var.env_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    "k8s-azure-service" = "${var.env_name}/nginx-service"
  }
}

# Azure Load Balancer
resource "azurerm_lb" "lb" {
  name                = "lb-${var.env_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = var.resource_group_name
#  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "lb-frontend"
    public_ip_address_id          = azurerm_public_ip.lb_ip.id
  }
}

# Backend Address Pool
resource "azurerm_lb_backend_address_pool" "example" {
  name           = "BackEndAddressPool"
  loadbalancer_id = azurerm_lb.lb.id
}

# Load Balancer Probe
#resource "azurerm_lb_probe" "example" {
#  name                = "lb-probe"
#  loadbalancer_id     = azurerm_lb.lb.id
  #protocol             = "Http"
#  port                 = 80
  #request_path         = "/"
#}

# Load Balancer Rule
#resource "azurerm_lb_rule" "example" {
#  name                           = "lb-rule"
#  loadbalancer_id                = azurerm_lb.lb.id
#  frontend_ip_configuration_name = "lb-frontend"
#  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.example.id]
#  probe_id                       = azurerm_lb_probe.example.id
#  protocol                       = "Tcp"
#  frontend_port                  = 80
#  backend_port                   = 80
#}