provider "azurerm" {
  version = "1.1"
}

resource "azurerm_resource_group" "rg" {
  name     = "test-rg"
  location = "westeurope"
}

resource "azurerm_network_security_group" "test-cluster-sg" {
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
}

resource "azurerm_virtual_network" "test-vnet" {
  name                = "rancher-vnet"
  location            = "${azurerm_resource_group.rg.location}"
  address_space       = ["10.0.0.0/16"]
  resource_group_name = "${azurerm_resource_group.rg.name}"
}

resource "azurerm_subnet" "test-instance-subnet" {
  name                 = "test-instances-subnet"
  virtual_network_name = "${azurerm_virtual_network.test-vnet.name}"
  resource_group_name  = "${azurerm_resource_group.rg.name}"
  address_prefix       = "10.0.0.0/24"
  network_security_group_id = "${azurerm_network_security_group.test-cluster-sg.id}"
}

resource "azurerm_public_ip" "testserver-pip" {
  name                         = "testserver-pip"
  location                     = "${azurerm_resource_group.rg.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  public_ip_address_allocation = "Dynamic"
}

resource "azurerm_network_interface" "testserver-nic" {
  name                = "testserver-nic"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  ip_configuration {
    name                          = "test-ipconfig"
    subnet_id                     = "${azurerm_subnet.test-instance-subnet.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.testserver-pip.id}"
  }
}

variable "ssh_public_key" {
  description = "Node public ssh key"
}

data "azurerm_public_ip" "testserver-pip" {
  name                = "${azurerm_public_ip.testserver-pip.name}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  depends_on          = ["azurerm_virtual_machine.bastion"]
}

resource "azurerm_virtual_machine" "bastion" {
  name                  = "bastion"
  location              = "${azurerm_resource_group.rg.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  vm_size               = "Standard_A1_v2"
  network_interface_ids = ["${azurerm_network_interface.testserver-nic.id}"]

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name          = "osdisk${count.index}"
    create_option = "FromImage"
  }

  delete_os_disk_on_termination = true

  os_profile {
    admin_username = "rke"
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

  depends_on = ["azurerm_virtual_machine.bastion"]

  connection {
    host        = "${data.azurerm_public_ip.testserver-pip.ip_address}" #dynamic ip causes connecting to old ip on recreate.
    type        = "ssh"
    user        = "rke"
    private_key = "${file("../.ssh_keys/id_rsa")}"
    timeout     = "1m"
    agent       = false
  }

  provisioner "file" {
    source      = "../scripts/install_kubectl.sh"
    destination = "/tmp/install_kubectl.sh"
  }

  provisioner "remote-exec" {

    inline = [
      "sudo chmod +x /tmp/install_kubectl.sh",
      "sudo /tmp/install_kubectl.sh"
    ]
  }
}
output "bastion-ip" {
  value = "${data.azurerm_public_ip.testserver-pip.ip_address}"
}
