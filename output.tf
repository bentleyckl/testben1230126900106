output "load_balancer_ip" {
  value = azurerm_public_ip.lb_ip.ip_address
}

output "aks_agentpool_public_ip" {
  value = data.azurerm_public_ip.aks_outbound_ip.ip_address
}