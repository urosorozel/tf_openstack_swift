```
virsh net-update --network bond0-network delete ip-dhcp-range "<range start='10.240.0.2' end='10.240.3.254'/>"  --live --config
virsh net-update --network bond0-network add ip-dhcp-range "<range start='10.240.0.2' end='10.240.0.50'/>"  --live --config
virsh net-update --network ironic-network add route "<route address='10.240.0.1' prefix='22' gateway='10.240.0.1'/>" --live --config 
```
```
sudo iptables -I POSTROUTING 4 -t nat -s 172.23.208.0/22 -d 10.240.0.0/22 -p tcp -j MASQUERADE --to-ports 1024-65535
sudo iptables -I POSTROUTING 4 -t nat -s 172.23.208.0/22 -d 10.240.0.0/22 -p udp -j MASQUERADE --to-ports 1024-65535
sudo iptables -I POSTROUTING 4 -t nat -s 172.23.208.0/22 -d 10.240.0.0/22 -p udp -j MASQUERADE
```

# Remove DHCP range

```
virsh net-update --network bond0-network delete ip-dhcp-range "<range start='10.240.0.2' end='10.240.3.254'/>"  --live --config
Updated network bond0-network persistent config and live state
```
### Check config
```
virsh net-dumpxml bond0-network
<network>
  <name>bond0-network</name>
  <uuid>2b30fccd-fea2-4598-bde5-8228a222dc4e</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='bond0-network' stp='on' delay='0'/>
  <mac address='52:54:00:8f:fe:26'/>
  <domain name='openstack.local' localOnly='yes'/>
  <dns enable='yes'/>
  <ip family='ipv4' address='10.240.0.1' prefix='22'>
  </ip>
</network>
```
# Update with new DCHP range
```
virsh net-update --network bond0-network add ip-dhcp-range "<range start='10.240.0.2' end='10.240.0.50'/>"  --live --config
Updated network bond0-network persistent config and live state
```

### Check config
```
virsh net-dumpxml bond0-network

<network>
  <name>bond0-network</name>
  <uuid>2b30fccd-fea2-4598-bde5-8228a222dc4e</uuid>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='bond0-network' stp='on' delay='0'/>
  <mac address='52:54:00:8f:fe:26'/>
  <domain name='openstack.local' localOnly='yes'/>
  <dns enable='yes'/>
  <ip family='ipv4' address='10.240.0.1' prefix='22'>
    <dhcp>
      <range start='10.240.0.2' end='10.240.0.50'/>
    </dhcp>
  </ip>
</network>
```

```
sudo ip link add veth_mgmt type veth peer name veth_control
sudo ip link add link veth_mgmt name veth_mgmt.100  type vlan id 100
sudo ip link show veth_mgmt.100
sudo brctl addif bond0-network veth_control
sudo ip link set dev veth_control up
sudo ip link set dev veth_mgmt up
sudo ip link set dev veth_mgmt.100 up
ip link show veth_mgmt.100
sudo ip addr add 172.29.236.110/22 dev veth_mgmt.100
```
* /etc/dhcp/dhclient.conf
```
send vendor-class-identifier = "PXEClient";
```

* Ignore all non pxe/inspector related requests
```
dhcp-ignore=tag:!PXEClient
dhcp-match=set:PXEClient,60,PXEClient
```

