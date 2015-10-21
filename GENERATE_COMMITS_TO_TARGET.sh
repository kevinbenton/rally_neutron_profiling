#!/bin/bash

THIS_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
COMMITS_TO_TARGET=$(awk 'NR == 1 || NR % 20 == 0' $THIS_DIR/ALL_COMMITS_IN_RANGE)

echo "$COMMITS_TO_TARGET" > "$THIS_DIR/COMMITS_TO_TARGET"

# correct filter field
echo "820199b23b6941e9628b85825539fb1cea51164f" >> "$THIS_DIR/COMMITS_TO_TARGET"

# defer JSON creation
echo "bcb2054de03888064fc8aa1b02a94db939725a57" >> "$THIS_DIR/COMMITS_TO_TARGET"

# Get all interfaces for get_snat_sync_interfaces
echo "26284228dfc3c5f121f869dd6b2d2a492afaf659" >> "$THIS_DIR/COMMITS_TO_TARGET"

# eliminate extra queries to retrieve gw_ports
echo "4b1bc776f581ec97b8b021728e79ec3c29823865" >> "$THIS_DIR/COMMITS_TO_TARGET"

# Replace unnecessary call to get_sync_routers
echo "5d427e225e7127dce66905d027728fda64e3fa03" >> "$THIS_DIR/COMMITS_TO_TARGET"


# L3 DB: Defer port DB subnet lookups
echo "27ab8e619324a212b54c431a9837cebe8beb3618" >> "$THIS_DIR/COMMITS_TO_TARGET"

# Remove double queries in l3 DB get methods
echo "b9d48c92542b0e8e90d1fe497bc45e221748bce5" >> "$THIS_DIR/COMMITS_TO_TARGET"

# set loading strategy to joined for Routerport
echo "145e0052d6a9d995da88940fdddcac016d23448a" >> "$THIS_DIR/COMMITS_TO_TARGET"

# Don't eagerly load ranges from IPAllocationPool
echo "ebb3c3f732d3fd0e227627175945c188bcf0a5cd" >> "$THIS_DIR/COMMITS_TO_TARGET"

# end
echo "822a488976ba6bf75ce89fff18992ad53ca7f326" >> "$THIS_DIR/COMMITS_TO_TARGET"
