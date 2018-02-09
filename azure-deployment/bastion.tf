resource "azurerm_public_ip" "bastion-pip" {
  name                         = "bastion-pip"
  location                     = "${azurerm_resource_group.rg.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  public_ip_address_allocation = "Dynamic"
  domain_name_label            = "${var.clustername}-bastion"
}

resource "azurerm_network_interface" "bastion-nic" {
  name                = "bastion-nic"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  ip_configuration {
    name                          = "bastion-ipconfig"
    subnet_id                     = "${azurerm_subnet.rancher-instance-subnet.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.bastion-pip.id}"
  }
}

resource "azurerm_virtual_machine" "bastion" {
  name                  = "bastion"
  location              = "${azurerm_resource_group.rg.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  vm_size               = "Standard_B1s"
  network_interface_ids = ["${azurerm_network_interface.bastion-nic.id}"]

  storage_image_reference {
    publisher = "${var.bastion_image_publisher}"
    offer     = "${var.bastion_image_offer}"
    sku       = "${var.bastion_image_sku}"
    version   = "${var.bastion_image_version}"
  }

  storage_os_disk {
    name          = "osdisk${count.index}"
    create_option = "FromImage"
  }

  delete_os_disk_on_termination = true

  os_profile {
    admin_username = "${var.admin_username}"
    computer_name = "node${count.index}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path = "/home/rke/.ssh/authorized_keys"
      key_data = "${var.ssh_public_key}"
    }
  }
}

resource "null_resource" "provision" {

  depends_on = ["azurerm_virtual_machine.master", "azurerm_virtual_machine.worker", "azurerm_virtual_machine.bastion", "azurerm_virtual_machine_extension.setup_master_docker_group", "azurerm_virtual_machine_extension.setup_worker_docker_group"]

  triggers {
    masters = "${join(",", azurerm_virtual_machine.master.*.id)}"
    workers = "${join(",", azurerm_virtual_machine.worker.*.id)}"
  }

  connection {
    host        = "${azurerm_public_ip.bastion-pip.fqdn}" #dynamic ip causes connecting to old ip on recreate.
    type        = "ssh"
    user        = "${var.admin_username}"
    private_key = "${file(".ssh_keys/id_rsa")}"
    timeout     = "1m"
    agent       = false
  }

  provisioner "file" {
    source      = "scripts/install_rke.sh"
    destination = "/tmp/install_rke.sh"
  }

  provisioner "file" {
    source      = "scripts/install_kubectl.sh"
    destination = "/tmp/install_kubectl.sh"
  }

  provisioner "file" {
    source      = "scripts/init_cluster.sh"
    destination = "/tmp/init_cluster.sh"
  }

  provisioner "file" {
    source      = ".ssh_keys"
    destination = "/home/rke/ssh_keys"
  }

  provisioner "remote-exec" {
    inline = [
      "echo '${file("./templates/rke_base.tpl")}' > /home/rke/cluster.yaml",
      "echo '${join("\n", data.template_file.rke_master_node_definition.*.rendered)}' >>  /home/rke/cluster.yaml",
      "echo '${join("\n", data.template_file.rke_worker_node_definition.*.rendered)}' >>  /home/rke/cluster.yaml",
      "sudo chmod +x /tmp/install_rke.sh",
      "sudo /tmp/install_rke.sh",
      "sudo chmod +x /tmp/install_kubectl.sh",
      "sudo /tmp/install_kubectl.sh",
      "rke up --config /home/rke/cluster.yaml",
      "mkdir -p /home/rke/.kube",
      "cp /home/rke/kube_config_cluster.yaml /home/rke/.kube/config",
      "chmod +x /tmp/init_cluster.sh"
    ]
  }
}

resource "null_resource" "init-cluster" {

  depends_on = ["null_resource.provision"]

  connection {
    host        = "${azurerm_public_ip.bastion-pip.fqdn}" #dynamic ip causes connecting to old ip on recreate.
    type        = "ssh"
    user        = "${var.admin_username}"
    private_key = "${file(".ssh_keys/id_rsa")}"
    timeout     = "1m"
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [
      "/tmp/init_cluster.sh",
    ]
  }

  provisioner "local-exec" {
    command = "mkdir -p .configs && scp -i .ssh_keys/id_rsa ${var.admin_username}@${azurerm_public_ip.bastion-pip.fqdn}:.kube/admin.kubeconfig .configs"
  }
}