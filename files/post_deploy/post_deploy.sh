#!/bin/bash
export CONTENT="Content-Type: application/json"
# openstack endpoint list --service placement  --interface admin -f value -c URL | xargs curl
export API='Openstack-API-Version: placement 1.10'
source openrc

#wget -q http://tarballs.openstack.org/ironic-python-agent/tinyipa/files/tinyipa-stable-rocky.vmlinuz  -O tinyipa_production_pxe.vmlinuz
#wget -q http://tarballs.openstack.org/ironic-python-agent/tinyipa/files/tinyipa-stable-rocky.gz -O tinyipa_production_pxe_image-oem.cpio.gz
# Load deployment image kernel into glance
#DEPLOY_VMLINUZ_UUID=$(openstack image create --container-format aki --disk-format aki --file tinyipa_production_pxe.vmlinuz tinyipa_kernel -f value -c id)
#DEPLOY_INITRD_UUID=$(openstack image create --container-format aki --disk-format aki --file tinyipa_production_pxe_image-oem.cpio.gz tinyipa_ramdisk -f value -c id)

# Clean up source files
#rm tinyipa_production_pxe.vmlinuz tinyipa_production_pxe_image-oem.cpio.gz

#guest_url=http://download.cirros-cloud.net/0.3.5/cirros-0.3.5-x86_64-disk.img
#guest_filename=${guest_url##*/}
#guest_ubuntu_url=http://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img
#guest_ubuntu_filename=${guest_ubuntu_url##*/}
#wget -q $guest_url -O $guest_filename
#wget -q $guest_ubuntu_url -O $guest_ubuntu_filename
#openstack image create --container-format bare --disk-format qcow2 --file $guest_filename $guest_filename
#openstack image create --container-format bare --disk-format qcow2 --file $guest_ubuntu_filename $guest_ubuntu_filename
#rm $guest_filename
#rm $guest_ubuntu_filename

#[ ! -f ~/.ssh/osa_key ]  && openstack keypair create --private-key  ~/.ssh/osa_key  osa_key
#chmod 0400 ~/.ssh/osa_key
# Flavors
#openstack --os-compute-api-version 2.55 flavor create --id 200 --ram 256 --disk 1 --vcpus 1 --description "Virtual flavor" --property baremetal=false virtual-flavor
# note: ram should be adjusted for physical servers (this will become the size of ramdisk)
#openstack --os-compute-api-version 2.55 flavor create --id 400 --ram 1024 --disk 10 --vcpus 1 --description "Baremetal flavor" --property baremetal=true baremetal-flavor

#nova flavor-key  baremetal-flavor  set cpu_arch=x86_64
#openstack aggregate set --property baremetal=false virtual-hosts
#openstack aggregate set --property baremetal=true baremetal-hosts


#TOKEN=$(openstack token issue -f value -c id)
#export TOKEN="X-Auth-Token: ${TOKEN}"

#PLACEMENT_API=$(openstack endpoint list --service placement  --interface internal -f value -c URL)

# Create custom resource class
#RS_PROVIDERS=/resource_providers
#DATA='{"name": "CUSTOM_BAREMETAL_SMALL"}'
#curl -s -X POST $PLACEMENT_API/resource_classes -H "$CONTENT" -H "$TOKEN" -H "$API" -d "$DATA"

#nova flavor-key baremetal-flavor set resources:CUSTOM_BAREMETAL_SMALL=1
#openstack flavor set baremetal-flavor --property "resources:CUSTOM_BAREMETAL_SMALL=1"
# enroll ironic nodes

#source enroll/bin/activate
#export OS_CACERT=''
#source openrc
#exit 0
#python enroll_ironic.py --deploy-kernel $DEPLOY_VMLINUZ_UUID  --deploy-ramdisk $DEPLOY_INITRD_UUID ironic_nodes.yml ironic_nodes.yml
# Wait for ironic nodes available in resource list
#sleep 80

# Attach custom resource class to ironic node resource inventory
#DATA='{"resource_provider_generation": 1, "inventories": {"VCPU": {"allocation_ratio": 1.0, "total": 1, "reserved": 0, "step_size": 1, "min_unit": 1, "max_unit": 1}, "MEMORY_MB": {"allocation_ratio": 1.0, "total": 1024, "reserved": 0, "step_size": 1, "min_unit": 1, "max_unit": 1024}, "DISK_GB": {"allocation_ratio": 1.0, "total": 10, "reserved": 0, "step_size": 1, "min_unit": 1, "max_unit": 10}, "CUSTOM_BAREMETAL_SMALL": {"allocation_ratio": 1.0, "total": 1, "reserved": 0, "step_size": 1, "min_unit": 1, "max_unit": 1}}}'
exit 0
for IRONIC in $(openstack  baremetal node list -f value -c UUID); do
  openstack  baremetal node set $IRONIC  --resource-class BAREMETAL_SMALL
  openstack  baremetal node manage $IRONIC
  openstack  baremetal node provide $IRONIC
  #PROVIDER=$(openstack resource provider list| grep $IRONIC| awk '{print $2}')
  #;echo $PROVIDER;done
  #curl -s -X PUT $PLACEMENT_API/resource_providers/$PROVIDER/inventories -H "$CONTENT" -H "$TOKEN" -H "$API" -d "$DATA" | python -m json.tool
done
sleep 80

# clean
# glance image-list | egrep -v '\+|ID' | awk '{ print $2}' | xargs glance image-delete
# nova flavor-list |egrep -v '\+|ID' | awk '{ print $4}' | xargs -Ixx nova flavor-delete xx
# ironic node-list | egrep -v '\+|ID' | awk '{ print $4}' | xargs -Ixx ironic node-delete xx

# boot
NET_IRONIC_UUID=$(openstack network list -f value | grep ironic-network | awk '{print $1}')
openstack server create --key-name osa_key  --flavor baremetal-flavor --image $guest_ubuntu_filename  --config-drive True --nic net-id=$NET_IRONIC_UUID baremetal1
openstack server create --key-name osa_key  --flavor baremetal-flavor --image $guest_ubuntu_filename  --config-drive True --nic net-id=$NET_IRONIC_UUID baremetal2

