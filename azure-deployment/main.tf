provider "azurerm" {
  version = "1.1"
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.clustername}-rg"
  location = "${var.location}"
}

resource "azurerm_network_interface" "worker-nic" {
  name                = "worker-nic-${count.index}"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  internal_dns_name_label = "worker-${count.index}"

  ip_configuration {
    name                          = "worker-ipconfig-${count.index}"
    subnet_id                     = "${azurerm_subnet.rancher-instance-subnet.id}"
    private_ip_address_allocation = "Dynamic"
  }

  count = "${var.worker_count}"
}

resource "azurerm_image" "ubuntu_docker" {
  name = "ubuntu_docker"
  location = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  os_disk {
    os_type = "Linux"
    os_state = "Generalized"
    blob_uri = "https://k8svhds.blob.core.windows.net/system/Microsoft.Compute/Images/ubuntu/ubuntu-docker-osDisk.d8a28c23-c69f-415d-8641-16afeda6ccf8.vhd"
    size_gb = 30
  }
}

resource "azurerm_virtual_machine" "worker" {
  name                  = "worker-node-${count.index}"
  location              = "${azurerm_resource_group.rg.location}"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  vm_size               = "${var.instance_size}"
  network_interface_ids = ["${element(azurerm_network_interface.worker-nic.*.id, count.index)}"]
  count                 = "${var.worker_count}"

  storage_image_reference {
    id = "${azurerm_image.ubuntu_docker.id}"
  }

  storage_os_disk {
    name          = "worker-osdisk-${count.index}"
    create_option = "FromImage"
  }

  delete_os_disk_on_termination = true

  os_profile {
    admin_username = "${var.admin_username}"
    computer_name = "worker-${count.index}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path = "/home/rke/.ssh/authorized_keys"
      key_data = "${var.ssh_public_key}"
    }
  }

  tags {
    role = "worker"
  }
}

resource "azurerm_virtual_machine_extension" "setup_worker_docker_group" {
  name = "worker-${count.index}-dockerGroup"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location = "${azurerm_resource_group.rg.location}"
  virtual_machine_name = "${element(azurerm_virtual_machine.worker.*.name, count.index)}"
  publisher = "Microsoft.Azure.Extensions"
  type = "CustomScript"
  type_handler_version = "2.0"
  auto_upgrade_minor_version = true
  count = "${var.worker_count}"
  depends_on = ["azurerm_virtual_machine.worker"]

  protected_settings = <<SETTINGS
   {
     "commandToExecute": "sudo usermod -a -G docker ${var.admin_username}"
   }
   SETTINGS
}

//resource "azurerm_public_ip" "master-pip" {
//  name                         = "master-pip-${count.index}"
//  location                     = "${azurerm_resource_group.rg.location}"
//  resource_group_name          = "${azurerm_resource_group.rg.name}"
//  public_ip_address_allocation = "Dynamic"
//  domain_name_label            = "${var.clustername}-${count.index}"
//
//  count = "${var.master_count}"
//}
//
//resource "azurerm_network_interface" "master-nic" {
//  name                = "master-nic-${count.index}"
//  location            = "${azurerm_resource_group.rg.location}"
//  resource_group_name = "${azurerm_resource_group.rg.name}"
//  internal_dns_name_label = "master-${count.index}"
//
//  ip_configuration {
//    name                          = "master-ipconfig-${count.index}"
//    subnet_id                     = "${azurerm_subnet.rancher-instance-subnet.id}"
//    private_ip_address_allocation = "Dynamic"
//    public_ip_address_id          = "${element(azurerm_public_ip.master-pip.*.id, count.index)}"
//  }
//
//  count = "${var.master_count}"
//}
//
//resource "azurerm_virtual_machine" "master" {
//  name                  = "master-node-${count.index}"
//  location              = "${azurerm_resource_group.rg.location}"
//  resource_group_name   = "${azurerm_resource_group.rg.name}"
//  vm_size               = "${var.instance_size}"
//  network_interface_ids = ["${element(azurerm_network_interface.master-nic.*.id, count.index)}"]
//  count                 = "${var.master_count}"
//
//  storage_image_reference {
//    id = "${azurerm_image.ubuntu_docker.id}"
//  }
//
//  storage_os_disk {
//    name          = "master-osdisk-${count.index}"
//    create_option = "FromImage"
//  }
//
//  delete_os_disk_on_termination = true
//
//  os_profile {
//    admin_username = "${var.admin_username}"
//    computer_name = "master-${count.index}"
//  }
//
//  os_profile_linux_config {
//    disable_password_authentication = true
//
//    ssh_keys {
//      path = "/home/rke/.ssh/authorized_keys"
//      key_data = "${var.ssh_public_key}"
//    }
//  }
//
//  tags {
//    role = "controlplane,etcd"
//  }
//}
//
//resource "azurerm_virtual_machine_extension" "setup_master_docker_group" {
//  name = "master-${count.index}-dockerGroup"
//  resource_group_name = "${azurerm_resource_group.rg.name}"
//  location = "${azurerm_resource_group.rg.location}"
//  virtual_machine_name = "${element(azurerm_virtual_machine.master.*.name, count.index)}"
//  publisher = "Microsoft.Azure.Extensions"
//  type = "CustomScript"
//  type_handler_version = "2.0"
//  auto_upgrade_minor_version = true
//  count = "${var.master_count}"
//  depends_on = ["azurerm_virtual_machine.master"]
//
//  protected_settings = <<SETTINGS
//   {
//     "commandToExecute": "sudo usermod -a -G docker ${var.admin_username}"
//   }
//   SETTINGS
//}

resource "random_string" "password" {
  length = 16
  special = true
}

resource "azurerm_public_ip" "master-pip" {
  name                         = "master-ip"
  location                     = "${azurerm_resource_group.rg.location}"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  public_ip_address_allocation = "Dynamic"
  domain_name_label            = "${var.clustername}"
}

resource "azurerm_lb" "master-lb" {
  name                = "rkeMasterLB"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  frontend_ip_configuration {
    name                 = "MasterPublicIPAddress"
    public_ip_address_id = "${azurerm_public_ip.master-pip.id}"
  }
}

resource "azurerm_lb" "master-ilb" {
  name                = "rkeMasterILB"
  location            = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  frontend_ip_configuration {
    name                 = "MasterPrivateIPAddress"
    subnet_id = "${azurerm_subnet.rancher-instance-subnet.id}"
    private_ip_address_allocation  = "Static"
    private_ip_address = "10.0.1.100"
  }
}

//data "azurerm_lb" "master-ilb" {
//  name                = "${azurerm_lb.master-ilb.name}"
//  resource_group_name = "${azurerm_resource_group.rg.name}"
//  depends_on          = ["azurerm_lb.master-ilb"]
//}

resource "azurerm_lb_backend_address_pool" "master-backend-pool" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.master-lb.id}"
  name                = "MasterBackEndAddressPool"
}

resource "azurerm_lb_backend_address_pool" "master-internalbackend-pool" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.master-ilb.id}"
  name                = "MasterInternalBackEndAddressPool"
}

resource "azurerm_lb_probe" "master-probe" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.master-lb.id}"
  name                = "master-running-probe"
  port                = "6443"
}

resource "azurerm_lb_probe" "master-internal-probe" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  loadbalancer_id     = "${azurerm_lb.master-ilb.id}"
  name                = "master-internal-running-probe"
  port                = "22"
}

resource "azurerm_lb_rule" "master-lbrkerule" {
  resource_group_name            = "${azurerm_resource_group.rg.name}"
  loadbalancer_id                = "${azurerm_lb.master-lb.id}"
  name                           = "rke"
  protocol                       = "Tcp"
  frontend_port                  = "6443"
  backend_port                   = "6443"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.master-backend-pool.id}"
  frontend_ip_configuration_name = "MasterPublicIPAddress"
  probe_id                       = "${azurerm_lb_probe.master-probe.id}"
}

resource "azurerm_lb_rule" "master-sshrule" {
  resource_group_name            = "${azurerm_resource_group.rg.name}"
  loadbalancer_id                = "${azurerm_lb.master-ilb.id}"
  name                           = "ssh"
  protocol                       = "Tcp"
  frontend_port                  = "22"
  backend_port                   = "22"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.master-internalbackend-pool.id}"
  frontend_ip_configuration_name = "MasterPrivateIPAddress"
  probe_id                       = "${azurerm_lb_probe.master-internal-probe.id}"
}

resource azurerm_virtual_machine_scale_set "master" {

  name = "masterscalegroup"
  location = "${azurerm_resource_group.rg.location}"
  resource_group_name = "${azurerm_resource_group.rg.name}"

  upgrade_policy_mode = "Manual"

  "sku" {
    capacity = 1
    name = "${var.instance_size}"
  }

  os_profile {
    admin_username = "${var.admin_username}"
    computer_name_prefix = "rkemaster-"
    admin_password = "${random_string.password.result}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path = "/home/rke/.ssh/authorized_keys"
      key_data = "${var.ssh_public_key}"
    }
  }

  storage_profile_image_reference {
    id = "${azurerm_image.ubuntu_docker.id}"
  }

  "storage_profile_os_disk" {
    name              = ""
    caching           = "ReadWrite"
    create_option = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  network_profile {
    name    = "rkemaster-nic"
    primary = true

    ip_configuration {
      name                                   = "rkemaster-ipconfig"
      subnet_id                              = "${azurerm_subnet.rancher-instance-subnet.id}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.master-backend-pool.id}", "${azurerm_lb_backend_address_pool.master-internalbackend-pool.id}"]
    }
  }

  extension {
    name = "master-dockerGroup"
    publisher = "Microsoft.Azure.Extensions"
    type = "CustomScript"
    type_handler_version = "2.0"

    protected_settings = <<SETTINGS
     {
       "commandToExecute": "sudo usermod -a -G docker ${var.admin_username}"
     }
     SETTINGS
  }

  tags {
    role = "controlplane,etcd"
  }

}