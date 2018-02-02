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
  domain_name_label            = "rkeclusternode${count.index}"

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

resource "azurerm_virtual_machine" "node" {
  name                  = "node${count.index}"
  location              = "${azurerm_resource_group.rg.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  vm_size               = "${var.vm_size}"
  network_interface_ids = ["${element(azurerm_network_interface.nic.*.id, count.index)}"]
  count                 = "${var.node_count}"

  storage_image_reference {
    publisher = "${var.image_publisher}"
    offer     = "${var.image_offer}"
    sku       = "${var.image_sku}"
    version   = "${var.image_version}"
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


resource "azurerm_virtual_machine_extension" "install_docker" {
  name                       = "node${count.index}-installDocker"
  resource_group_name        = "${azurerm_resource_group.rg.name}"
  location                   = "${azurerm_resource_group.rg.location}"
  virtual_machine_name       = "${element(azurerm_virtual_machine.node.*.name, count.index)}"
  publisher                  = "Microsoft.Azure.Extensions"
  type                       = "CustomScript"
  type_handler_version       = "2.0"
  auto_upgrade_minor_version = true
  count                      = "${var.node_count}"
  depends_on                 = ["azurerm_virtual_machine.node"]


  protected_settings = <<SETTINGS
 {
   "commandToExecute": "sudo apt install -y docker.io && sudo usermod -a -G docker ${var.admin_username}"
 }
SETTINGS
}

//resource "azurerm_virtual_machine_extension" "setup_docker_group" {
//  name                       = "node${count.index}-dockerGroup"
//  resource_group_name        = "${azurerm_resource_group.rg.name}"
//  location                   = "${azurerm_resource_group.rg.location}"
//  virtual_machine_name       = "${element(azurerm_virtual_machine.node.*.name, count.index)}"
//  publisher                  = "Microsoft.Azure.Extensions"
//  type                       = "CustomScript"
//  type_handler_version       = "2.0"
//  auto_upgrade_minor_version = true
//  count                      = "${var.node_count}"
//  depends_on                 = ["azurerm_virtual_machine.node"]
//
//
//  protected_settings = <<SETTINGS
// {
//   "commandToExecute": "sudo usermod -a -G docker ${var.admin_username}"
// }
//SETTINGS
//}