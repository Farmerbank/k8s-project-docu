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

resource "azurerm_image" "ubuntu_bastion" {
  name = "ubuntu_bastion"
  location = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  os_disk {
    os_type = "Linux"
    os_state = "Generalized"
    blob_uri = "https://k8svhds.blob.core.windows.net/system/Microsoft.Compute/Images/ubuntu/ubuntu-bastion-osDisk.6251f6bb-e465-4077-aaeb-bd20fe43a3a1.vhd"
  }
}

resource "azurerm_virtual_machine" "bastion" {
  name                  = "bastion"
  location              = "${azurerm_resource_group.rg.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  vm_size               = "Standard_A1_v2"
  network_interface_ids = ["${azurerm_network_interface.bastion-nic.id}"]

  storage_image_reference {
    id = "${azurerm_image.ubuntu_bastion.id}"
  }

  storage_os_disk {
    name          = "osdisk${count.index}"
    create_option = "FromImage"
  }

  delete_os_disk_on_termination = true

  os_profile {
    admin_username = "${var.admin_username}"
    computer_name = "bastion"
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

//  depends_on = ["azurerm_virtual_machine.master", "azurerm_virtual_machine.worker", "azurerm_virtual_machine.bastion", "azurerm_virtual_machine_extension.setup_master_docker_group", "azurerm_virtual_machine_extension.setup_worker_docker_group"]

  depends_on = ["azurerm_virtual_machine_scale_set.master", "azurerm_virtual_machine.worker", "azurerm_virtual_machine.bastion", "azurerm_virtual_machine_extension.setup_worker_docker_group"]

  triggers {
    //masters = "${join(",", azurerm_virtual_machine.master.*.id)}"
    lb = "${azurerm_lb.master-lb.id}"
    master = "${azurerm_virtual_machine_scale_set.master.id}"
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
    command = "mkdir -p .configs && scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i .ssh_keys/id_rsa ${var.admin_username}@${azurerm_public_ip.bastion-pip.fqdn}:.kube/admin.kubeconfig .configs"
  }
}