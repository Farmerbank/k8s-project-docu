provider "azurerm" {
  version = "1.1"
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.resource_group}"
  location = "${var.location}"
}

resource "azurerm_virtual_network" "rke" {
  name                = "rke_network"
  location            = "${azurerm_resource_group.rg.location}"
  address_space       = ["${var.address_space}"]
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

resource "azurerm_subnet" "nodes" {
  name                 = "nodes"
  virtual_network_name = "${azurerm_virtual_network.rke.name}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  address_prefix       = "${var.nodes_subnet}"
  network_security_group_id = "${azurerm_network_security_group.nodes.id}"
}

resource "azurerm_network_security_group" "nodes" {
  name                = "nodes"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "RKE"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "etcd"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "2379-2380"
    source_address_prefix      = "*"
    destination_address_prefix = "${var.nodes_subnet}"
  }

  security_rule {
    name                       = "kubelet_api"
    priority                   = 103
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10250"
    source_address_prefix      = "*"
    destination_address_prefix = "${var.nodes_subnet}"
  }

  security_rule {
    name                       = "scheduler"
    priority                   = 104
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10251"
    source_address_prefix      = "*"
    destination_address_prefix = "${var.nodes_subnet}"
  }

  security_rule {
    name                       = "controller"
    priority                   = 105
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10252"
    source_address_prefix      = "*"
    destination_address_prefix = "${var.nodes_subnet}"
  }

  security_rule {
    name                       = "kubeproxy"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "10256"
    source_address_prefix      = "*"
    destination_address_prefix = "${var.nodes_subnet}"
  }

  security_rule {
    name                       = "nodeport_services"
    priority                   = 121
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "30000-32767"
    source_address_prefix      = "*"
    destination_address_prefix = "${var.nodes_subnet}"
  }
}

resource "azurerm_public_ip" "pip" {
  name                         = "ip${count.index}"
  location                     = "${azurerm_resource_group.rg.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  public_ip_address_allocation = "Dynamic"
  domain_name_label            = "${var.fqdn_label_prefix}${count.index}"

  count = "${var.node_count}"
}

resource "azurerm_network_interface" "nic" {
  name                = "nic${count.index}"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  ip_configuration {
    name                          = "ipconfig${count.index}"
    subnet_id                     = "${azurerm_subnet.nodes.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${element(azurerm_public_ip.pip.*.id, count.index)}"
  }

  count = "${var.node_count}"
}

resource "azurerm_image" "hostos" {
  name = "hostos"
  location = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  os_disk {
    os_type = "Linux"
    os_state = "Generalized"
    blob_uri = "https://k8svhds.blob.core.windows.net/system/Microsoft.Compute/Images/ubuntu/ubuntu-docker-osDisk.d8a28c23-c69f-415d-8641-16afeda6ccf8.vhd"
    size_gb = 30
  }
}

resource "azurerm_virtual_machine" "node" {
  name                  = "node${count.index}"
  location              = "${azurerm_resource_group.rg.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  vm_size               = "${var.vm_size}"
  network_interface_ids = ["${element(azurerm_network_interface.nic.*.id, count.index)}"]
  count                 = "${var.node_count}"

//  storage_image_reference {
//    publisher = "${var.image_publisher}"
//    offer     = "${var.image_offer}"
//    sku       = "${var.image_sku}"
//    version   = "${var.image_version}"
//  }

  storage_image_reference {
    id = "${azurerm_image.hostos.id}"
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

  connection {
    host        = "${element(azurerm_public_ip.pip.*.fqdn, count.index)}" #dynamic ip causes connecting to old ip on recreate.
    type        = "ssh"
    user        = "${var.admin_username}"
    private_key = "${file("./.ssh_keys/id_rsa")}"
    timeout     = "1m"
    agent       = false
  }

//  provisioner "file" {
//    source      = "./install_docker.sh"
//    destination = "/tmp/install_docker.sh"
//  }

//  provisioner "remote-exec" {
//    inline = [
//      "sudo chmod +x /tmp/install_docker.sh",
//      "sudo /tmp/install_docker.sh"
//    ]
//  }

  provisioner "remote-exec" {
    inline = [
      "sudo usermod -aG docker ${var.admin_username}"
    ]
  }
}