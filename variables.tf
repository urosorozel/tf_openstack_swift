variable "domain_name" {
    description = "Openstack hosts domain name"
    default  = "openstack.net"
}

variable "openstack_bond0_network" {
    description = "Subnet cidr for openstack hosts"
    default  = "10.240.0.0/22"
}

variable "openstack_ironic_network" {
    description = "Subnet cidr for openstack ironic hosts"
    default = "172.23.208.0/22"
}

variable "openstack_bond1_network" {
    description = "Subnet cidr for openstack compute"
    default = "192.168.236.0/22"
}

variable "storage_pool" {
    description = "Storage pool path"
    default  = "/libvirt_pool"
}

variable "storage_pool_name" {
    description = "Storage pool name"
    default  = "openstack_pool"
} 

variable "qcow_image_filename" {
    description = "QCOW2 image filename."
    default  = "ubuntu-bionic.qcow2"
}

variable "qcow_image_path" {
    description = "QCOW2 image path."
    default  = "/home/uros"
}

variable "control_node_prefix" {
    description = "Control node prefix."
    default  = "control"
}

variable "control_node_count" {
    description = "The number of control nodes."
    default  = "3"
}

variable "control_node_cpu" {
    description = "Control node cpu's."
    default  = "4"
}

variable "control_node_memory" {
    description = "Control node memory."
    default  = "16384"
}

variable "control_node_disk" {
    description = "Control node disk size."
    default  = "85899345920"
}

variable "control_disks" {
    description = "Control node Swift disks."
    default  = "3"
}

variable "control_node_vlan" {
  type = "map"

  default = {
    br_mgmt = "172.29.236.10/22"
    br_ovs = "172.29.240.10/22"
    br_storage = "172.29.244.10/22"
    br_repl = "172.29.248.10/22"
    ip_offset = 10 
    netmask = 22
  }
}

variable "infra_node_prefix" {
    description = "Infra node prefix."
    default  = "haproxy"
}

variable "infra_node_count" {
    description = "The number of infra nodes."
    default  = "2"
}

variable "infra_node_cpu" {
    description = "Infra node cpu's."
    default  = "2"
}

variable "infra_node_memory" {
    description = "Infra node memory."
    default  = "4096"
}

variable "infra_node_disk" {
    description = "Infranode disk size."
    default  = "21474836480"
}

variable "infra_node_vlan" {
  type = "map"

  default = {
    br_mgmt = "172.29.236.10/22"
    br_ovs = "172.29.240.10/22"
    br_storage = "172.29.244.10/22"
    br_repl = "172.29.248.10/22"
    ip_offset = 16
    netmask = 22
  }
}

variable "ironic_node_prefix" {
    description = "Ironic node prefix."
    default  = "ironic"
}

variable "ironic_node_count" {
    description = "The number of ironic nodes."
    default  = "2"
}

variable "ironic_node_cpu" {
    description = "Ironic node cpu's."
    default  = "2"
}

variable "ironic_node_memory" {
    description = "Ironic node memory."
    default  = "6144"
}

variable "ironic_node_disk" {
    description = "Ironic node disk size."
    default  = "21474836480"
}

variable "ssh_authorized_key" {
    description = "SSH authorized key"
    default  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDIic9Z0cLKnEuLm5XXS7/b3wF5GRC14+FoUi2dXEyqKP9gjV4PstSA++WAOAy3X3mAz9SG7JPB+g0zwiB0DDC+AjWY8BreU4wVquJ6AhHCCzFeRrc/7CyGSG7fJ3NDKIP74VMD8mz3xY9VoUDQRCMwh9jF3fSq3xIxpwu2E/2fwc7Pq3VfFZ5x07v9+ptSI/MiBqKac4Qt2r2MzD9fzb+Z7T65iSwhOR5zaOPeY8fP/7oOWaTuR/P4vuv7d83SgZAPOwgNZxYd/3OuwtgSFr3jQVln/QxpDC0ZUQpiL7pEmyFTwLOBnqInmcHgWCX0qFfkwZdfu/8goWPNDh1T0SEV uros@cba-cp-b-new"
}

