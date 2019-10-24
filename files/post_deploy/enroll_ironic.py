#!/usr/bin/env python
from __future__ import print_function

from pprint import pprint
import ironicclient
from ironicclient import client

import ruamel.yaml as yaml

import sys
import os
import argparse
import uuid

import structlog
from structlog.processors import TimeStamper

structlog.configure(processors=[structlog.processors.TimeStamper( fmt="iso", utc=True, key='timestamp'), structlog.processors.KeyValueRenderer(key_order=['timestamp'])])
log = structlog.getLogger()
parser = argparse.ArgumentParser(
    description="Add/update nodes in ironic from the infrastructure.yml file")

parser.add_argument("--limit", dest="limit", nargs="*",
                    help="Limit operations to the named list of nodes")
parser.add_argument("--exclude", dest="exclude", nargs="*",
                    help="Exclude specific nodes from the operation")

parser.add_argument("--deploy-kernel", dest="deploy_kernel",
                    nargs=1, help="Deploy kernel for the new node", required=True)
parser.add_argument("--deploy-ramdisk", dest="deploy_ramdisk",
                    nargs=1, help="Deploy ramdisk for the new node", required=True)

parser.add_argument(dest="definition_file", help="YAML node definition file")
parser.add_argument(
    dest="output_file", help="Output file for updated infrastructure YAML. Default is stdout.")

args = parser.parse_args()


ironic = client.get_client(1,
                           os_cacert=os.environ['OS_CACERT'],
                           auth_url=os.environ['OS_AUTH_URL'],
                           username=os.environ['OS_USERNAME'],
                           password=os.environ['OS_PASSWORD'],
                           user_domain_name=os.environ[
                               'OS_USER_DOMAIN_NAME'],
                           project_domain_name=os.environ[
                               'OS_PROJECT_DOMAIN_NAME'],
                           project_name=os.environ['OS_PROJECT_NAME'],
                           endpoint_type=os.environ['OS_ENDPOINT_TYPE'],
                           baremetal_api_version=os.environ['OS_BAREMETAL_API_VERSION'],
                           os_ironic_api_version=os.environ['OS_BAREMETAL_API_VERSION'],
                           insecure=True)

infrastructure = yaml.load(
    open(args.definition_file, "r"), yaml.RoundTripLoader)

limitSet = set()
if args.limit is not None:
    for node in args.limit:
        limitSet.add(node)
    log.info("Limiting operations to: {}".format(','.join(limitSet)))
else:
    # Add all nodes to the limit set.
    for node in infrastructure['ironic_nodes']:
        limitSet.add(node['name'])

excludeSet = set()
if args.exclude is not None:
    for node in args.exclude:
        excludeSet.add(node)
    log.info("Excluding operations on: {}".format(','.join(excludeSet)))


for node in infrastructure['ironic_nodes']:
    log = log.bind(name=node['name'])

    if node['name'] not in limitSet:
        log.debug("Skipping node not in limit set")
        continue

    if node['name'] in excludeSet:
        log.debug("Skipping node due to exclusion")
        continue

    if 'static' in node:
        if node['static']:
            log.info("Not adding node - marked as statically configured")
            continue

    # Add node
    ipmi_address = node['ipmi_interface']['ip_address']
    ipmi_port = node['ipmi_interface']['ip_port']
    ipmi_username = node['ipmi_interface']['username']
    ipmi_password = node['ipmi_interface']['password']
    hw_properties = node['hardware_type']
    boot_mode = node['hardware_type']['mode']

    if boot_mode == "uefi":
       capabilities = "boot_mode:uefi"

    if boot_mode == "bios":
       capabilities = "boot_option:local"

    ironic_uuid = node['node_uuid']
    if ironic_uuid is None:
        ironic_uuid = str(uuid.uuid4())

    ironicnode = {
        "name": node['name'],
        "uuid": ironic_uuid,
        "driver": "ipmi",
        "deploy_interface": "direct",
        "driver_info": {
            "ipmi_address": ipmi_address,
            "ipmi_port": ipmi_port,
            "ipmi_username": ipmi_username,
            "ipmi_password": ipmi_password,
            "deploy_kernel": args.deploy_kernel[0],
            "deploy_ramdisk": args.deploy_ramdisk[0],
            "rescue_kernel": args.deploy_kernel[0],
            "rescue_ramdisk": args.deploy_ramdisk[0]
        },
        "properties": {
            "cpus": hw_properties['cpus'],
            "cpu_arch": hw_properties['cpu_arch'],
            "memory_mb": hw_properties['memory_mb'],
            "local_gb": hw_properties['local_gb'],
            "capabilities": capabilities
        }
    }

    # ironic node ports
    primary_nic = node['primary_interface']
    if primary_nic['mac_address'] is None or primary_nic['mac_address'] == "":
        continue
    openstack_port_uuid = primary_nic['interface_uuid']
    if openstack_port_uuid is None:
        openstack_port_uuid = str(uuid.uuid4())

    ironicport = {
        "uuid": openstack_port_uuid,
        "node_uuid": ironicnode['uuid'],
        "address": primary_nic['mac_address']
    }

    # Determine if we're creating or patching
    created_node = False
    try:
        inode = ironic.node.get(ironicnode['uuid'])
        log.info("Found existing ironic node", uuid=inode.uuid)
    except ironicclient.common.apiclient.exceptions.NotFound:
        log.info("Creating ironic node", uuid=ironicnode['uuid'])
        # Create node
        try:
            inode = ironic.node.create(**ironicnode)
            created_node = True
        except ironicclient.common.apiclient.exceptions.Conflict as e:
            inode = ironic.node.get(ironicnode['name'])
            ironic_uuid = inode.uuid
            log.error("Node already exists, updating UUID", uuid=ironic_uuid)
        except Exception as e:
            log.error("Failed to create node: {} {}".format(type(e), e))
            continue
    node['node_uuid'] = ironic_uuid


    try:
        iport = ironic.port.get(ironicport['uuid'])
        print(ironicport)
        log.info("Found existing port for node", ironic_port_uuid=iport.uuid)
    except ironicclient.common.apiclient.exceptions.NotFound:
        log.info("Port does not exist: attempting to create")
        try:
            print(ironicport)
            log.info("Creating port with uuid: %s" % ironicport['uuid'])
            iport = ironic.port.create(**ironicport)
            node['primary_interface']['interface_uuid'] = iport.uuid
            log.info("Port created: %s" % iport.uuid)
        except:
            iport = ironic.port.get_by_address(ironicport['address'])
            log.error(
                "Primary port already exists, updating UUID", uuid=iport.uuid)
            node['primary_interface']['interface_uuid'] = iport.uuid
            if created_node:
                log.error(
                    "Failed to create port for node - reverting node creation", ironic_port_uuid=iport.uuid)
                ironic.node.delete(inode.uuid)
                node['node_uuid'] = None


f = sys.stdout
if args.output_file is not None:
    f = open(args.output_file, "w")

yaml.dump(infrastructure, f, Dumper=yaml.RoundTripDumper,
          default_flow_style=False)

sys.exit(0)
