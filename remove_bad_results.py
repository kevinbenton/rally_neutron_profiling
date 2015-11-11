with open('BAD_RESULTS', 'r') as h:
    bad = [line.split('bad results for commit ')[1].strip()
           for line in h.readlines() if line.startswith('bad results ')]
    print bad
with open('PROFILED_COMMITS', 'r+') as h:
    orig = h.readlines()
    h.seek(0)
    for line in orig:
        if line.split(',')[0] not in bad:
            h.write(line)
        else:
            print 'removed commit %s' % line.split(',')[0]
    h.truncate()
