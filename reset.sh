#!/bin/bash
function cleanimports {
find . -name "*.py" -print | xargs sed -i 's/from oslo.config/from oslo_config/g' &
find neutron -name "*.py" -print | xargs sed -i 's/from oslo.db/from oslo_db/g' 
find neutron -name "*.py" -print | xargs sed -i 's/from oslo.serialization/from oslo_serialization/g' 
find neutron -name "*.py" -print | xargs sed -i 's/from oslo.messaging/from oslo_messaging/g' 
find . -name "*.py" -print | xargs sed -i 's/from oslo.utils/from oslo_utils/g' 
find neutron -name "*.py" -print | xargs sed -i 's/oslo.i18n/oslo_i18n/g' 
find neutron -name "*.py" -print | xargs sed -i 's/from oslo import i18n/import oslo_i18n as i18n/g' 
find neutron -name "*.py" -print | xargs sed -i 's/from oslo import messaging/import oslo_messaging as messaging/g' 
find neutron -name "*.py" -print | xargs sed -i 's/oslo\.messaging\./oslo_messaging./g'
wait
}
sudo rm -r /tmp/pip*
cd /opt/stack/neutron/
echo "drop database neutron" | mysql -u root -pkevin
echo "create database neutron" | mysql -u root -pkevin
grep -R 1680e1f0c4dc neutron/db/migration/alembic_migrations/
if [ $? -eq 0 ]; then
    mysql -u root -pkevin neutron < ~/rally_neutron_profiling/base_fixed.mysqldump
else
    mysql -u root -pkevin neutron < ~/rally_neutron_profiling/libbase.mysqldump
fi
grep testresources test-requirements.txt
if [ $? -ne 0 ]; then
    echo testresources >> test-requirements.txt
fi
FPATH='neutron/db/migration/alembic_migrations/versions/2b801560a332_remove_hypervneutronplugin_tables.py'
if [ -e $FPATH ]; then
    cp ~/rally_neutron_profiling/2b801560a332.py $FPATH
fi
sudo rm -rf /usr/local/lib/python2.7/dist-packages/neutron
sudo rm -rf /usr/local/lib/python2.7/dist-packages/neutron.egg-link
sudo rm -rf /usr/local/lib/python2.7/dist-packages/neutron-*
#sudo rm -rf .tox/py27
find . -name "*.pyc" -exec rm -rf {} \;
git reset --hard
git clean -fd

cat >> neutron/common/constants.py << HERE
RPC_NAMESPACE_DHCP_PLUGIN = None 
RPC_NAMESPACE_METADATA = None
RPC_NAMESPACE_SECGROUP = None
RPC_NAMESPACE_DVR = None
RPC_NAMESPACE_STATE = None
HERE
rm -rf neutron/tests/functional/contrib
sed -i 's/<=0.8.99,//g' requirements.txt
cleanimports
#tox -vr -epy27 test_exceptions_notimplemented
sleep 0.05
if [ $? -ne 0 ]; then
    sudo pip install tox==1.9
    tox -v -epy27 test_exceptions_notimplemented
fi
if [ $? -ne 0 ]; then
    sudo pip install tox==2.1.1
    tox -v -epy27 test_exceptions_notimplemented
fi
cleanimports
source .tox/py27/bin/activate
pip install pbr --upgrade
yes | pip uninstall neutron
pip install .
pip install pymysql
.tox/py27/bin/neutron-db-manage --config-file /etc/neutron/neutron.conf upgrade head
.tox/py27/bin/neutron-db-manage --config-file /etc/neutron/neutron.conf upgrade head
