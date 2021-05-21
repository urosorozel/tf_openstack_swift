variable "domain_name" {
    description = "Openstack hosts domain name"
    default  = "openstack-aio.net"
}

variable "openstack_aio_network" {
    description = "Subnet cidr for openstack_aio hosts"
    default  = "10.200.0.0/24"
}

variable "openstack_aio_ironic_network" {
    description = "Subnet cidr for openstack_aio ironic hosts"
    default = "172.20.200.0/22"
}

variable "storage_pool" {
    description = "Storage pool path"
    default  = "/libvirt_pool"
}

variable "storage_pool_name" {
    description = "Storage pool name"
    default  = "openstack_aio_pool"
} 

variable "qcow_image_filename" {
    description = "QCOW2 image filename."
    default  = "ubuntu-bionic.qcow2"
}

variable "qcow_image_path" {
    description = "QCOW2 image path."
    default  = "/home/uros"
}

variable "aio_node_prefix" {
    description = "Control node prefix."
    default  = "aio"
}

variable "aio_node_count" {
    description = "The number of aio nodes."
    default  = "1"
}

variable "aio_node_cpu" {
    description = "Control node cpu's."
    default  = "4"
}

variable "aio_node_memory" {
    description = "Control node memory."
    default  = "16384"
}

variable "aio_node_disk" {
    description = "Control node disk size."
    default  = "85899345920"
}


variable "aio_node_vlan" {
  type = "map"

  default = {
    ens3 = "10.200.0.100/24"
    ens3_gateway = "10.200.0.1"
    br_mgmt = "172.29.236.100/22"
    br_ovs = "172.29.240.10/22"
    br_storage = "172.29.244.10/22"
    br_pxe = "172.20.200.10/22"
    ip_offset = 10 
    netmask = 22
  }
}

variable "ssh_authorized_key" {
    description = "SSH authorized key"
    default  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDIic9Z0cLKnEuLm5XXS7/b3wF5GRC14+FoUi2dXEyqKP9gjV4PstSA++WAOAy3X3mAz9SG7JPB+g0zwiB0DDC+AjWY8BreU4wVquJ6AhHCCzFeRrc/7CyGSG7fJ3NDKIP74VMD8mz3xY9VoUDQRCMwh9jF3fSq3xIxpwu2E/2fwc7Pq3VfFZ5x07v9+ptSI/MiBqKac4Qt2r2MzD9fzb+Z7T65iSwhOR5zaOPeY8fP/7oOWaTuR/P4vuv7d83SgZAPOwgNZxYd/3OuwtgSFr3jQVln/QxpDC0ZUQpiL7pEmyFTwLOBnqInmcHgWCX0qFfkwZdfu/8goWPNDh1T0SEV uros@cba-cp-b-new"
}

