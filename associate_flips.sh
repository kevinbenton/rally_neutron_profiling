#!/bin/bash
source ~/devstack/openrc admin admin

function setup_flip_for_port {
   pid=$1
   neutron floatingip-create EXTERNAL --port-id $pid
}

i=0
for port in $(neutron port-list -c id -c device_owner -f value | grep -v 'network:'); do
    i=$((i+1))
    setup_flip_for_port $port &
    sleep 0.08
    if [ $i -gt 40 ]; then
        i=0
        wait
    fi
done
