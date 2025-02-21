output "load_balancer_ip" {
  value       = data.external.public_ip.result["ip"]
  description = "Please use this IP to access index.html"
}