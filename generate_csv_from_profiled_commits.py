#!/usr/bin/env python
import eventlet
eventlet.monkey_patch()
import StringIO
import csv
import os
import subprocess
import json


RFILE = os.path.join(os.path.dirname(os.path.realpath(__file__)), 'results.csv')


def get_commit_rally_map():
    pool = eventlet.GreenPool(14)
    workers = {}
    commit_rally_id_map = {}
    with open(os.path.join(os.path.dirname(os.path.realpath(__file__)),
                           'PROFILED_COMMITS'), 'r') as handle:
        for line in handle.readlines():
            try:
                commit, remainder = line.split(',')
            except ValueError:
                continue
            try:
                rally_id = remainder.split('results ')[-1].strip()
            except IndexError:
                print 'invalid rally run for commit %s' % commit
                continue
            commit_rally_id_map[commit] = rally_id
    for commit, rally_id in commit_rally_id_map.items():
        workers[commit] = pool.spawn(get_rally_results, rally_id)
    commit_rally_map = {commit: w.wait() for commit, w in workers.items()}
    return commit_rally_map


def ascending_commits():
    with open(os.path.join(os.path.dirname(os.path.realpath(__file__)),
                           'COMMITS_TO_TARGET'), 'r') as handle:
        return [line.split(' ')[0] for line in handle.readlines()]


def get_rally_results(rally_id):
    output = subprocess.Popen(["rally", "task", "results", rally_id],
                              stdout=subprocess.PIPE).communicate()[0]
    try:
        results = json.loads(output)
    except ValueError:
        return None
    return results

def generate_csv_line(commit, results):
    # order of CSV:
    # commit, total_duration,
    # neutron.rpc_sg_info_for_devices_full_id (avg/max),
    # neutron.rpc_get_devices_details_list (avg/max),
    # neutron.rpc_get_routers (agv/max)
    tests_to_get = ['neutron.rpc_sg_info_for_devices_full_id',
                    'neutron.rpc_get_devices_details_list',
                    'neutron.rpc_get_routers']
    runs = {k: [] for k in tests_to_get}
    totals = {k: 0.0 for k in tests_to_get}
    maxes = {k: 0.0 for k in tests_to_get}
    counts = {k: 0 for k in tests_to_get}
    total_duration = 0.0
    for result in results:
        for run in result['result']:
            total_duration += run['duration']
            for t in tests_to_get:
                if t not in run['atomic_actions']:
                    print '%s not found in %s' % (t, run['atomic_actions'])
                    print 'bad results for commit %s' % commit
                    return False    
                runs[t].append(run['atomic_actions'][t])
                counts[t] += 1
                totals[t] += run['atomic_actions'][t]
                maxes[t] = max(maxes[t], run['atomic_actions'][t])
    line = [commit, total_duration]
    for t in tests_to_get:
        # each run
        for r in runs[t]:
            line.append(r)
        # avg
        line.append(totals[t]/counts[t])
        # max
        line.append(maxes[t])
    return list_to_csv(line)


def get_csv_header():
    headers = ['commit', 'total_duration']
    tests = ['neutron.rpc_sg_info_for_devices_full_id',
             'neutron.rpc_get_devices_details_list',
             'neutron.rpc_get_routers']
    for t in tests:
        for i in range(1, 3):
            headers.append('%s (run %s)' % (t, i))
        headers.append('%s (avg)' % t)
        headers.append('%s (max)' % t)
    return list_to_csv(headers)


def list_to_csv(lst):
    st = StringIO.StringIO()
    cw = csv.writer(st)
    cw.writerow(lst)
    return st.getvalue().strip('\r\n')


def run():
    commit_rally_map = get_commit_rally_map()
    lines = [get_csv_header()]
    for commit in ascending_commits():
        if commit not in commit_rally_map:
            print 'commit %s did not have rally results' % commit
            # not a profiled commit
            continue
        if not commit_rally_map[commit]:
            print 'bad results for commit %s' % commit
            continue
        result = generate_csv_line(
            commit, commit_rally_map[commit])
        if result:
            lines.append(result)
    with open(RFILE, 'w') as handle:
        handle.write('\n'.join(lines))


if __name__ == '__main__':
    run()
