output "nodes" {
  value = ["${azurerm_public_ip.pip.*.fqdn}"]
}
