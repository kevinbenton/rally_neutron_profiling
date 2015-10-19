#!/bin/bash
cd /opt/stack/neutron/
echo "drop database neutron;" | mysql -u root -pkevin
echo "create database neutron;" | mysql -u root -pkevin
sudo rm -rf /usr/local/lib/python2.7/dist-packages/neutron
sudo rm -rf /usr/local/lib/python2.7/dist-packages/neutron.egg-link
sudo rm -rf /usr/local/lib/python2.7/dist-packages/neutron-*
sudo rm -rf .tox/py27
tox -vr -epy27 noopas
source .tox/py27/bin/activate
pip install .
pip install pymysql
.tox/py27/bin/neutron-db-manage --config-file /etc/neutron/neutron.conf upgrade head
