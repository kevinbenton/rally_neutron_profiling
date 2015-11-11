#!/bin/bash
function rneutron {
   i=1
   while [ $i -lt 10 ]; do
     neutron $1 > /dev/null
     if [ $? -eq 0 ]; then
         return
     fi
     i=$((i+1))
   done
}
function make_set {
    ID=$1
    rneutron "-q -r 5 router-create ROUTER-$ID "
    rneutron "-q -r 5 net-create NET-$ID "
    rneutron "-q -r 5 subnet-create NET-$ID 192.168.0.0/24 --name SUBNET-$ID-A "
    rneutron "-q -r 5 subnet-create NET-$ID 192.168.1.0/24 --name SUBNET-$ID-B "
    rneutron "-q -r 5 router-interface-add ROUTER-$ID SUBNET-$ID-A "
    rneutron "-q -r 5 router-interface-add ROUTER-$ID SUBNET-$ID-B "
    rneutron "-q -r 5 router-gateway-set ROUTER-$ID EXTERNAL "
    rneutron "-q -r 5 security-group-create SG-$ID "
    for j in {101..125}; do
        rneutron "-q -r 5 security-group-rule-create SG-$ID --protocol tcp --port-range-min $j --port-range-max  $j "
    done
    for k in {1..5}; do
        rneutron "-q -r 5 port-create --security-group SG-$ID NET-$ID "
    done
}
for n in {4..84}; do
	for i in {1..12}; do
	    make_set "$n-$i" &
        done
        wait
        echo "DONE WITH ITERATION $n"
done
