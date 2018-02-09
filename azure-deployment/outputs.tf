output "bastion" {
  value = "${azurerm_public_ip.bastion-pip.fqdn}"
}

output "workers" {
  value = ["${azurerm_network_interface.worker-nic.*.internal_fqdn}"]
}

output "masters" {
  value = ["${azurerm_public_ip.master-pip.*.fqdn}"]
}
