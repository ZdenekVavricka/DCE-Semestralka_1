
terraform {
  required_providers {
    opennebula = {
      source = "OpenNebula/opennebula"
      version = "~> 1.2"
    }
  }
}
provider "opennebula" {
  endpoint      = "${var.one_endpoint}"
  username      = "${var.one_username}"
  password      = "${var.one_password}"
}

# resource "opennebula_image" "os-image" {
#     name = "${var.vm_image_name}"
#     datastore_id = "${var.vm_imagedatastore_id}"
#     persistent = false
#     path = "${var.vm_image_url}"
#     permissions = "600"
# }

resource "opennebula_virtual_machine" "controller-node" {
  name = "controller-node"
  description = "Controller node VM"
  cpu = 1
  vcpu = 1
  memory = 2048
  permissions = "600"
  group = "users"

  context = {
    NETWORK  = "YES"
    HOSTNAME = "$NAME"
    SSH_PUBLIC_KEY = "${var.vm_ssh_pubkey}"
  }
  os {
    arch = "x86_64"
    boot = "disk0"
  }
  disk {
#    image_id = opennebula_image.os-image.id
    image_id = 687
    target   = "vda"
    size     = 12000 # 12GB
  }

  graphics {
    listen = "0.0.0.0"
    type   = "vnc"
  }

  nic {
    network_id = var.vm_network_id
  }

  connection {
    type = "ssh"
    user = "root"
    host = "${self.ip}"
    private_key = "${file("/var/iac-dev-container-data/id_ecdsa")}"
  }

  provisioner "file" {
    source = "init-scripts/"
    destination = "/tmp"
  }

  provisioner "remote-exec" {
    inline = [
      "export INIT_USER=${var.vm_admin_user}",
      "export INIT_PUBKEY='${var.vm_ssh_pubkey}'",
      "export INIT_LOG=${var.vm_node_init_log}",
      "export INIT_HOSTNAME=${self.name}",
      "touch ${var.vm_node_init_log}",
      "sh /tmp/init-start.sh",
      "sh /tmp/init-node.sh",
      "sh /tmp/init-users.sh",
      "sh /tmp/init-finish.sh"
    ]
  }

  tags = {
    role = "controller"
  }

}

resource "opennebula_virtual_machine" "compute-node" {
  # This will create `vm_instance_count` instances:
  count = var.compute_nodes_count
  name = "compute-node-${count.index + 1}"
  description = "Compute node VM #${count.index + 1}"
  cpu = 1
  vcpu = 1
  memory = 2048
  permissions = "600"
  group = "users"

  context = {
    NETWORK  = "YES"
    HOSTNAME = "$NAME"
    SSH_PUBLIC_KEY = "${var.vm_ssh_pubkey}"
  }
  os {
    arch = "x86_64"
    boot = "disk0"
  }
  disk {
    # image_id = opennebula_image.os-image.id
    image_id = 687
    target   = "vda"
    size     = 12000 # 12GB
  }

  graphics {
    listen = "0.0.0.0"
    type   = "vnc"
  }

  nic {
    network_id = var.vm_network_id
  }

  connection {
    type = "ssh"
    user = "root"
    host = "${self.ip}"
    private_key = "${file("/var/iac-dev-container-data/id_ecdsa")}"
  }

  provisioner "file" {
    source = "init-scripts/"
    destination = "/tmp"
  }

  provisioner "remote-exec" {
    inline = [
      "export INIT_USER=${var.vm_admin_user}",
      "export INIT_PUBKEY='${var.vm_ssh_pubkey}'",
      "export INIT_LOG=${var.vm_node_init_log}",
      "export INIT_HOSTNAME=${self.name}",
      "touch ${var.vm_node_init_log}",
      "sh /tmp/init-start.sh",
      "sh /tmp/init-node.sh",
      "sh /tmp/init-users.sh",
      "sh /tmp/init-finish.sh"
    ]
  }

  tags = {
    role = "compute"
  }

}

#-------OUTPUTS ------------

output "controller_node" {
  value = "${opennebula_virtual_machine.controller-node.*.ip}"
}

output "compute_nodes" {
  value = "${opennebula_virtual_machine.compute-node.*.ip}"
}

resource "local_file" "hosts_cfg" {
  content = templatefile("inventory.tmpl",
    {
      vm_admin_user = var.vm_admin_user,
      controller_node = opennebula_virtual_machine.controller-node.*.ip,
      compute_nodes = opennebula_virtual_machine.compute-node.*.ip
    })
  filename = "./dynamic_inventories/cluster"
}

#
# EOF
#
