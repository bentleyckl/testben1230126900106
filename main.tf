resource "azurerm_resource_group" "benrg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.env-name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.0.0.0/16"]
}


resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.env-name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "Allow-All-Inbound"
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


resource "azurerm_subnet" "public" {
  name                 = "public-subnet-${var.env-name}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}


resource "azurerm_subnet_network_security_group_association" "public_nsg_assoc" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}


resource "azurerm_subnet" "private" {
  name                 = "private-subnet-${var.env-name}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}


resource "azurerm_kubernetes_cluster" "aks" {
  name                = "k8cluster-${var.env-name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "k8cluster-${var.env-name}"

  default_node_pool {
    name       = "agentpool"
    node_count = 1
    vm_size    = "Standard_D2s_v3"
  }

  identity {
    type = "SystemAssigned"
  }
}


resource "azurerm_public_ip" "lb_ip" {
  name                = "lb-ip-${var.env-name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  allocation_method   = "Static"
}


resource "azurerm_lb" "lb" {
  name                = "lb-${var.env-name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  frontend_ip_configuration {
    name                 = "lb-frontend"
    public_ip_address_id = azurerm_public_ip.lb_ip.id
  }
}


resource "kubernetes_namespace" "nginx" {
  metadata {
    name = var.env-name
  }
}


resource "kubernetes_config_map" "index_html" {
  metadata {
    name      = "index-config"
    namespace = kubernetes_namespace.nginx.metadata[0].name
  }

  data = {
    "index.html" = "<html><body><h1>This is ${var.env-name} environment.</h1></body></html>"
  }
}


resource "kubernetes_deployment" "nginx" {
  metadata {
    name      = "nginx"
    namespace = kubernetes_namespace.nginx.metadata[0].name
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "nginx"
      }
    }

    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }

      spec {
        container {
          name  = "nginx"
          image = "nginx"

          port {
            container_port = 80
          }

          volume_mount {
            name       = "index-html"
            mount_path = "/usr/share/nginx/html"
          }
        }

        volume {
          name = "index-html"

          config_map {
            name = kubernetes_config_map.index_html.metadata[0].name
          }
        }
      }
    }
  }
}


resource "kubernetes_service" "nginx" {
  metadata {
    name      = "nginx-service"
    namespace = kubernetes_namespace.nginx.metadata[0].name
  }

  spec {
    type = "LoadBalancer"

    selector = {
      app = "nginx"
    }

    port {
      port        = 80
      target_port = 80
    }
  }
}

data "azurerm_public_ip" "aks_outbound_ip" {
  name                = "${azurerm_kubernetes_cluster.aks.name}-agentpool"
  resource_group_name = azurerm_kubernetes_cluster.aks.node_resource_group
}