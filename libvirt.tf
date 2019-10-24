provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_pool" "openstack_pool" {
  name = var.storage_pool_name
  type = "dir"
  path = "${var.storage_pool}/${var.storage_pool_name}"

}


resource "libvirt_network" "openstack_bond0_network" {
  name      = "bond0-network"
  bridge    = "bond0-network"
  mtu       = 9000
  mode      = "nat"
  domain    = "${var.domain_name}"
  addresses = [var.openstack_bond0_network]
  dhcp {
	enabled = true
  }
  dns {
    enabled = true
    local_only = true
  }
#  provisioner "local-exec" {
#    command = "virsh net-update --network bond0-network delete ip-dhcp-range '<range start='10.240.0.2' end='10.240.3.254'/>'  --live --config
#               virsh net-update --network bond0-network add ip-dhcp-range '<range start='10.240.0.2' end='10.240.0.50'/>'  --live --config"
#  }
}

resource "libvirt_network" "openstack_ironic_network" {
  name      = "ironic-network"
  mode      = "nat"
  bridge    = "ironic-network"
  addresses = [var.openstack_ironic_network]
  dhcp {
        enabled = false
  }
  dns {
    enabled = false
    local_only = true
  }
  #routes {
  #    cidr = "10.240.0.0/22"
  #    gateway = "10.240.0.1"
  #}
}

resource "libvirt_network" "openstack_bond1_network" {
  name      = "bond1-network"
  mode      = "nat"
  bridge    = "bond1-network"
  mtu       = 9000
  addresses = [var.openstack_bond1_network]
  dhcp {
        enabled = false
  }
  dns {
    enabled = false
    local_only = true
  }
}

data "template_file" "control_user_data" {
  template = "${file("${path.module}/cloudinit/cloud_init.yml")}"

  vars = {
    user_name          = "ubuntu"
    ssh_authorized_key = "${var.ssh_authorized_key}"
  }
}

data "template_file" "control_meta_data" {
  count    = "${var.control_node_count}"
  template = "${file("${path.module}/cloudinit/meta_data.yml")}"

  vars = {
    hostname = "${format("${var.control_node_prefix}-%02d", count.index + 1)}"
  }
}

data "template_file" "control_network_config" {
  count    = "${var.control_node_count}"
  template = "${file("${path.module}/cloudinit/network_config.yml")}"

  vars = {
    br_mgmt = cidrhost(var.control_node_vlan.br_mgmt, count.index + 1 + var.control_node_vlan.ip_offset)
    br_ovs = cidrhost(var.control_node_vlan.br_ovs, count.index + 1 + var.control_node_vlan.ip_offset)
    br_storage = cidrhost(var.control_node_vlan.br_storage, count.index + 1 + var.control_node_vlan.ip_offset)
    br_repl = cidrhost(var.control_node_vlan.br_repl, count.index + 1 + var.control_node_vlan.ip_offset)
  }
}

resource "libvirt_cloudinit_disk" "control_commoninit" {
  count          = "${var.control_node_count}"
  name           = "${format("${var.control_node_prefix}-seed-%01d.iso", count.index + 1)}"
  pool           = libvirt_pool.openstack_pool.name
  user_data      = "${data.template_file.control_user_data.rendered}"
  meta_data      = "${data.template_file.control_meta_data.*.rendered[count.index]}"
  network_config = "${data.template_file.control_network_config.*.rendered[count.index]}"
}

resource "libvirt_volume" "ubuntu-image" {
  name = "${var.qcow_image_filename}"
  pool = libvirt_pool.openstack_pool.name
  source = "${var.qcow_image_path}/${var.qcow_image_filename}"
  format = "qcow2"
  depends_on = [libvirt_pool.openstack_pool]
}

resource "libvirt_volume" "master-deploy-image" {
  name = "${var.control_node_prefix}-${count.index}.qcow2"
  base_volume_id = libvirt_volume.ubuntu-image.id
  pool = libvirt_pool.openstack_pool.name
  size = "${var.control_node_disk}" 
  format = "qcow2"
  count = "${var.control_node_count}"
  depends_on = [libvirt_pool.openstack_pool]
}

# Volume

locals {
  product = "${setproduct(range(var.control_node_count), range(var.control_disks))}"
}

resource "libvirt_volume" "swift-disk" {
  name = "${var.control_node_prefix}-${element(local.product, count.index)[0]}-disk${element(local.product, count.index)[1]}.qcow2"
  pool = libvirt_pool.openstack_pool.name
  size = "${var.control_node_disk}"
  format = "qcow2"
  count     = "${var.control_node_count * var.control_disks}"
  depends_on = [libvirt_pool.openstack_pool]
}

# Define KVM domain to create
resource "libvirt_domain" "control_nodes" {
  name   = "${var.control_node_prefix}-${count.index}"
  memory = "${var.control_node_memory}"
  vcpu   = "${var.control_node_cpu}"

  network_interface {
    network_name = libvirt_network.openstack_bond0_network.name
    wait_for_lease = false
  }
  network_interface {
    network_name = libvirt_network.openstack_bond1_network.name
    wait_for_lease = false
  }
  network_interface {
    network_name = libvirt_network.openstack_ironic_network.name
    wait_for_lease = false
  }
  disk {
    volume_id = "${element(libvirt_volume.master-deploy-image,count.index).id}"
  }

  dynamic "disk" {
    for_each = range(var.control_disks)
      content {
         volume_id = "${var.storage_pool}/${var.storage_pool_name}/${var.control_node_prefix}-${count.index}-disk${disk.value}.qcow2"
      }
  }
  cloudinit = "${element(libvirt_cloudinit_disk.control_commoninit,count.index).id}"

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  console {
      type        = "pty"
      target_type = "virtio"
      target_port = "1"
  }

  graphics {
    type = "vnc"
    listen_type = "address"
    listen_address = "10.184.227.238"
    autoport = true
  }
  count = "${var.control_node_count}"
  depends_on = [libvirt_pool.openstack_pool,libvirt_network.openstack_bond0_network,libvirt_volume.swift-disk]
}

# END MASTER
resource "libvirt_volume" "infra-deploy-image" {
  name = "${var.infra_node_prefix}-${count.index}.qcow2"
  base_volume_id = libvirt_volume.ubuntu-image.id
  pool = libvirt_pool.openstack_pool.name
  size = "${var.infra_node_disk}"
  format = "qcow2"
  count = "${var.infra_node_count}"
  depends_on = [libvirt_pool.openstack_pool]
}

data "template_file" "infra_user_data" {
  template = "${file("${path.module}/cloudinit/cloud_init.yml")}"

  vars = {
    user_name          = "ubuntu"
    ssh_authorized_key = "${var.ssh_authorized_key}"
  }
}

data "template_file" "infra_meta_data" {
  count    = "${var.infra_node_count}"
  template = "${file("${path.module}/cloudinit/meta_data.yml")}"

  vars = {
    hostname = "${format("${var.infra_node_prefix}-%02d", count.index + 1)}"
  }
}

data "template_file" "bond1_network_config" {
  count    = "${var.infra_node_count}"
  template = "${file("${path.module}/cloudinit/network_config.yml")}"

  vars = {
    br_mgmt = cidrhost(var.infra_node_vlan.br_mgmt, count.index + 1 + var.infra_node_vlan.ip_offset)
    br_ovs = cidrhost(var.infra_node_vlan.br_ovs, count.index + 1 + var.infra_node_vlan.ip_offset)
    br_storage = cidrhost(var.infra_node_vlan.br_storage, count.index + 1 + var.infra_node_vlan.ip_offset)
    br_repl = cidrhost(var.infra_node_vlan.br_repl, count.index + 1 + var.infra_node_vlan.ip_offset)
  }
}


resource "libvirt_cloudinit_disk" "infra_commoninit" {
  count          = "${var.infra_node_count}"
  name           = "${format("${var.infra_node_prefix}-seed-%01d.iso", count.index + 1)}"
  pool           = libvirt_pool.openstack_pool.name
  user_data      = "${data.template_file.infra_user_data.rendered}"
  meta_data      = "${data.template_file.infra_meta_data.*.rendered[count.index]}"
  network_config = "${data.template_file.bond1_network_config.*.rendered[count.index]}"
}

# Define KVM domain to create
resource "libvirt_domain" "infra_nodes" {
  name   = "${format("${var.infra_node_prefix}-%02d", count.index + 1)}"
  memory = "${var.infra_node_memory}"
  vcpu   = "${var.infra_node_cpu}"

  network_interface {
    network_name = libvirt_network.openstack_bond0_network.name
    wait_for_lease = false
  }

#  network_interface {
#    network_name = libvirt_network.openstack_bond1_network.name
#    wait_for_lease = false
#  }

  disk {
    volume_id = "${element(libvirt_volume.infra-deploy-image,count.index).id}"
  }

  cloudinit = "${element(libvirt_cloudinit_disk.infra_commoninit,count.index).id}"

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  console {
      type        = "pty"
      target_type = "virtio"
      target_port = "1"
  }

  graphics {
    type = "vnc"
    listen_type = "address"
    listen_address = "10.184.227.238"
    autoport = true
  }
  count = "${var.infra_node_count}"
  depends_on = [libvirt_pool.openstack_pool,libvirt_network.openstack_bond0_network,libvirt_volume.infra-deploy-image]
}

# END HAPROXY

resource "libvirt_volume" "ironic-deploy-image" {
  name = "${var.ironic_node_prefix}-${count.index}.qcow2"
  pool = libvirt_pool.openstack_pool.name
  size = "${var.ironic_node_disk}"
  format = "qcow2"
  count = "${var.ironic_node_count}"
  depends_on = [libvirt_pool.openstack_pool]
}

resource "libvirt_domain" "ironic_nodes" {
  name   = "${format("${var.ironic_node_prefix}-%02d", count.index + 1)}"
  memory = "${var.ironic_node_memory}"
  vcpu   = "${var.ironic_node_cpu}"

  network_interface {
    network_name = libvirt_network.openstack_ironic_network.name
    mac = "${format("52:54:00:b6:fc:%02d", count.index + 1)}"
    wait_for_lease = false
  }
  disk {
    volume_id = "${element(libvirt_volume.ironic-deploy-image,count.index).id}"
  }

  console {
    type = "pty"
    target_type = "serial"
    target_port = "0"
  }

  console {
      type        = "pty"
      target_type = "virtio"
      target_port = "1"
  }

  boot_device {
    dev = ["hd", "network"]
  }

  graphics {
    type = "vnc"
    listen_type = "address"
    listen_address = "10.184.227.238"
    autoport = true
  }
  count = "${var.ironic_node_count}"
  depends_on = [libvirt_pool.openstack_pool,libvirt_network.openstack_ironic_network,libvirt_volume.ironic-deploy-image]
}
# END IRONIC

resource "ansible_host" "control_nodes" {
    inventory_hostname = "${format("${var.control_node_prefix}-%02d", count.index + 1)}.${var.domain_name}"
    groups = ["controller","openstack-cluster","master"]
    vars = {
        ansible_user = "ubuntu"
        #ansible_host = "${element(libvirt_domain.control_nodes,count.index).network_interface.0.addresses.0}"
         ansible_host = "${format("${var.control_node_prefix}-%02d", count.index + 1)}.${var.domain_name}"
        #access_ip = "${element(libvirt_domain.control_nodes,count.index).network_interface.0.addresses.0}"
    }
    count = "${var.control_node_count}"
    depends_on = [libvirt_domain.control_nodes]
}


resource "ansible_host" "infra_nodes" {
    inventory_hostname = "${format("${var.infra_node_prefix}-%02d", count.index + 1)}.${var.domain_name}"
    groups = ["openstack-cluster","infra"]
    vars = {
        ansible_user = "ubuntu"
        #ansible_host = "${element(libvirt_domain.infra_nodes,count.index).network_interface.0.addresses.0}"
        ansible_host = "${format("${var.infra_node_prefix}-%02d", count.index + 1)}.${var.domain_name}"
        #access_ip = "${element(libvirt_domain.infra_nodes,count.index).network_interface.0.addresses.0}"
    }
    count = "${var.infra_node_count}"
    depends_on = [libvirt_domain.infra_nodes]
}



#output "control_ips" {
#  value = libvirt_domain.control_nodes.*.network_interface.0.addresses
#}
#
#output "compute_ips" {
#  value = libvirt_domain.compute_nodes.*.network_interface.0.addresses
#}
#
#output "mon_ips" {
#  value = libvirt_domain.mon_nodes.*.network_interface.0.addresses
#}
#
#output "infra_ips" {
#  value = libvirt_domain.infra_nodes.*.network_interface.0.addresses
#}
#
#output "ceph_osd_ips" {
#  value = libvirt_domain.ceph_osd_nodes.*.network_interface.0.addresses
#}
