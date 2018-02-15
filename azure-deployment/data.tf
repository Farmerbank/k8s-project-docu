data "template_file" "rke_master_node_definition" {
  count    = "${var.master_count}"
  template = "${file("templates/rke_node.tpl")}"
  vars {
//    public_dns = "${azurerm_public_ip.master-pip.*.fqdn[count.index]}"
//    internal_address = "${azurerm_network_interface.master-nic.*.private_ip_address[count.index]}"
//    role = "${azurerm_virtual_machine.master.*.tags.role[count.index]}"
    public_dns = "${azurerm_public_ip.master-pip.fqdn}"
    internal_address = "${azurerm_lb.master-ilb.private_ip_address}"
    role = "${azurerm_virtual_machine_scale_set.master.tags.role}"
  }
}

data "template_file" "rke_worker_node_definition" {
  count    = "${var.worker_count}"
  template = "${file("templates/rke_node.tpl")}"
  vars {
    public_dns = "${azurerm_network_interface.worker-nic.*.internal_fqdn[count.index]}"
    internal_address = "${azurerm_network_interface.worker-nic.*.private_ip_address[count.index]}"
    role = "${azurerm_virtual_machine.worker.*.tags.role[count.index]}"
  }
}