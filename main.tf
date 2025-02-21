
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-${var.env_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "aks-${var.env_name}"

  default_node_pool {
    name           = "agentpool"
    node_count     = 1
    vm_size        = "Standard_D2s_v3"
    vnet_subnet_id = azurerm_subnet.private.id
    #os_disk_size_gb = 200 # I have added 200GB disk to comfirm if this is the root cause
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin     = "azure"
    network_plugin_mode = "overlay"
    service_cidr       = "172.16.0.0/16"
    dns_service_ip     = "172.16.0.10"
    pod_cidr           = "192.168.0.0/16"
  }
}

# Kubernetes Namespace
resource "kubernetes_namespace" "nginx" {
  metadata {
    name = var.env_name
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

# Kubernetes ConfigMap
resource "kubernetes_config_map" "index_html" {
  metadata {
    name      = "index-config"
    namespace = kubernetes_namespace.nginx.metadata[0].name
  }

  data = {
    "index.html" = "<html><body><h1>This is ${var.env_name} environment.</h1></body></html>"
  }

  depends_on = [azurerm_kubernetes_cluster.aks]
}

# Kubernetes Deployment
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

  depends_on = [azurerm_kubernetes_cluster.aks]
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

  timeouts {
    create = "10m" 
  }
}

data "external" "public_ip" {
  depends_on = [kubernetes_service.nginx]
  program = ["powershell", "-Command", "$ip = az network public-ip list --query '[1].ipAddress' --output tsv; $json = @{ip=$ip} | ConvertTo-Json -Compress; Write-Output $json"]
}
