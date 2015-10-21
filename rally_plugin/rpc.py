# Copyright 2014 Big Switch Networks
# All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

import sys

import eventlet
from oslo_config import cfg

from rally.common import utils as rutils
from rally.plugins.openstack import scenario
from rally.plugins.openstack.scenarios.neutron import utils
from rally.plugins.openstack.wrappers import network as network_wrapper
from rally.task import atomic
from rally.task import validation
from rally import consts
import requests

SG_PORT_INCR = rutils.RAMInt()


class NeutronRPC(utils.NeutronScenario):


    @validation.required_services(consts.Service.NEUTRON)
    @validation.required_openstack(users=True)
    @scenario.configure(context={"cleanup": ["neutron"]})
    def rpc_routers_ports_security_groups(self,
                                          number_of_net_router_sets=10,
                                          number_of_sg_rules=10,
                                          number_of_ports_per_network=10):
        """Create a ports and then retrieve them via RPC.

        """
        pool = eventlet.GreenPool()
        net_workers = []
        for i in range(number_of_net_router_sets):
            net_workers.append(
                pool.spawn(self._create_network_and_subnets,
                           {}, {}, 1, '10.90.0.0/24'))
        ext_net = self._create_network({'router:external': True})
        ext_sub = self._create_subnet(ext_net, {})
        nets_and_subs = [w.wait() for w in net_workers]
        routers = []
        port_workers = []
        for network, subnets in nets_and_subs:
            router = self._create_router(
                {'external_gateway_info': {
                    'network_id': ext_net["network"]["id"]}})
            pool.spawn(self.clients("neutron").add_interface_router,
                router["router"]["id"],
                {"subnet_id": subnets[0]["subnet"]["id"]})
            routers.append(router)
            for i in range(number_of_ports_per_network):
                port_workers.append(
                    pool.spawn(self._create_port, network, {}))
        ports = [w.wait() for w in port_workers]
        sg_id = ports[0]['port']['security_groups'][0]
        for i in range(number_of_sg_rules):
            port = 100 + next(SG_PORT_INCR)
            sg_body = {'security_group_rule': {
              "direction": "ingress", "port_range_min": str(port),
              "ethertype": "IPv4", "port_range_max": str(port),
              "protocol": "tcp", "security_group_id": sg_id}}
            pool.spawn(self.clients("neutron").create_security_group_rule, sg_body)
        pool.waitall()
        if not self.rpc_security_group_info_for_devices_full_ids(ports):
            raise Exception("rpc_security_group_info_for_devices_full_ids returned empty")
        if not self.rpc_security_group_info_for_devices_short_ids(ports):
            raise Exception("rpc_security_group_info_for_devices_short_ids returned empty")
        if not self.rpc_get_devices_details_list(ports):
            raise Exception("rpc_get_devices_details_list returned empty")
        if not self.rpc_get_routers(routers):
            raise Exception("rpc_get_routers returned empty")

    @atomic.action_timer('neutron.rpc_sg_info_for_devices_full_id')
    def rpc_security_group_info_for_devices_full_ids(self, ports):
        port_ids = [p['port']['id'] for p in ports]
        return requests.get(
            'http://localhost:18888/sg/security_group_info_for_devices/%s'
            % ','.join(port_ids)).json()

    @atomic.action_timer('neutron.rpc_sg_info_for_devices_short_id')
    def rpc_security_group_info_for_devices_short_ids(self, ports):
        port_ids = ['tap%s' % p['port']['id'][0:8] for p in ports]
        return requests.get(
            'http://localhost:18888/sg/security_group_info_for_devices/%s'
            % ','.join(port_ids)).json()

    @atomic.action_timer('neutron.rpc_get_devices_details_list')
    def rpc_get_devices_details_list(self, ports):
        port_ids = [p['port']['id'] for p in ports]
        return requests.get(
            'http://localhost:18888/l2/get_devices_details_list/%s'
            % ','.join(port_ids)).json()

    @atomic.action_timer('neutron.rpc_get_routers')
    def rpc_get_routers(self, routers):
        router_ids = [router['router']['id'] for router in routers]
        return requests.get(
            'http://localhost:18888/l3/get_routers/%s'
            % ','.join(router_ids)).json()
