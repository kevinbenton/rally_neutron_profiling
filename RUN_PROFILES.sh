#!/bin/bash
set -x

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOG_DIR=${THIS_DIR}/logs/
NEUTRON_DIR=/opt/stack/neutron/

function neutron_procs {
    ps -ef | grep neutron-server | grep -v grep | awk '{ print $2 }'
}

function kill_neutron {
   local iter_count=0;
   while [ -n "$(neutron_procs)" ]; do
       iter_count=$((iter_count+1))
       for pid in $(neutron_procs); do
           if [[ $iter_count -lt 8 ]]; then
               kill $pid
           else
               kill -9 $pid
           fi
           sleep 0.25
           break
       done
   done
}

function start_neutron {
   bash $THIS_DIR/reset.sh >> $LOG_DIR/rally_neutron_server.log 2>&1
   source $NEUTRON_DIR/.tox/py27/bin/activate
   python $NEUTRON_DIR/.tox/py27/bin/neutron-server --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini >> $LOG_DIR/rally_neutron_server.log 2>&1 &
   local iter_count=0;
   nc -z localhost 9696
   while [ $? -ne 0 ]; do
       iter_count=$((iter_count+1))
       sleep 0.25
       if [[ $iter_count -lt 20 ]]; then
           nc -z localhost 9696
       fi
   done
}

function switch_to_sha {
   cd $NEUTRON_DIR
   git checkout $1
}

function check_sha_profiled {
   grep $1 $THIS_DIR/PROFILED_COMMITS
}

function log_sha_rally_profile {
   echo "$1,$2" >> $THIS_DIR/PROFILED_COMMITS
}

function run_rally_task {
    cd /opt/stack/neutron
    rally task start ~/.rally/plugins/neutron-rpc.yaml 2>&1 | tee $LOG_DIR/rally_run_log.log
}

COMMITS_TO_TARGET=$(awk 'NR == 1 || NR % 20 == 0' $THIS_DIR/ALL_COMMITS_IN_RANGE)

while read -r line; do
    echo "profiling $line"
    sha=$(echo $line | awk '{ print $1 }');
    check_sha_profiled $sha
    if [ $? -eq 0 ]; then
        echo "$sha has been profiled"
        continue
    fi
    kill_neutron
    switch_to_sha $sha
    start_neutron
    run_rally_task
    rally_resp=$(cat $LOG_DIR/rally_run_log.log | grep 'rally task results ')
    echo "profiling for $sha done with $rally_resp"
    log_sha_rally_profile "$sha" "$rally_resp"

done <<< "$COMMITS_TO_TARGET"


