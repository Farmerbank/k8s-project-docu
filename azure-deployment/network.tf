resource "azurerm_network_security_group" "rancher-cluster-sg" {
  name                = "rancher-instances-sg"
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

//  security_rule {
//    name                       = "etcd"
//    priority                   = 102
//    direction                  = "Inbound"
//    access                     = "Allow"
//    protocol                   = "Tcp"
//    source_port_range          = "*"
//    destination_port_range     = "2379-2380"
//    source_address_prefix      = "*"
//    destination_address_prefix = "${var.nodes_subnet}"
//  }
//
//  security_rule {
//    name                       = "kubelet_api"
//    priority                   = 103
//    direction                  = "Inbound"
//    access                     = "Allow"
//    protocol                   = "Tcp"
//    source_port_range          = "*"
//    destination_port_range     = "10250"
//    source_address_prefix      = "*"
//    destination_address_prefix = "${var.nodes_subnet}"
//  }
//
//  security_rule {
//    name                       = "scheduler"
//    priority                   = 104
//    direction                  = "Inbound"
//    access                     = "Allow"
//    protocol                   = "Tcp"
//    source_port_range          = "*"
//    destination_port_range     = "10251"
//    source_address_prefix      = "*"
//    destination_address_prefix = "${var.nodes_subnet}"
//  }
//
//  security_rule {
//    name                       = "controller"
//    priority                   = 105
//    direction                  = "Inbound"
//    access                     = "Allow"
//    protocol                   = "Tcp"
//    source_port_range          = "*"
//    destination_port_range     = "10252"
//    source_address_prefix      = "*"
//    destination_address_prefix = "${var.nodes_subnet}"
//  }
//
//  security_rule {
//    name                       = "kubeproxy"
//    priority                   = 120
//    direction                  = "Inbound"
//    access                     = "Allow"
//    protocol                   = "Tcp"
//    source_port_range          = "*"
//    destination_port_range     = "10256"
//    source_address_prefix      = "*"
//    destination_address_prefix = "${var.nodes_subnet}"
//  }
//
//  security_rule {
//    name                       = "nodeport_services"
//    priority                   = 121
//    direction                  = "Inbound"
//    access                     = "Allow"
//    protocol                   = "Tcp"
//    source_port_range          = "*"
//    destination_port_range     = "30000-32767"
//    source_address_prefix      = "*"
//    destination_address_prefix = "${var.nodes_subnet}"
//  }
}

resource "azurerm_virtual_network" "rancher-vnet" {
  name                = "rancher-vnet"
  location            = "${azurerm_resource_group.rg.location}"
  address_space       = ["${var.address_space}"]
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

resource "azurerm_subnet" "rancher-instance-subnet" {
  name                 = "rancher-instances-subnet"
  virtual_network_name = "${azurerm_virtual_network.rancher-vnet.name}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  address_prefix       = "${var.nodes_subnet}"
  network_security_group_id = "${azurerm_network_security_group.rancher-cluster-sg.id}"
}