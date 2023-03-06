#!/bin/bash

set -eu
cd "$(dirname "$0")"

CURRENT_CLUSTER="$(lxc remote get-default)"

if echo "$CURRENT_CLUSTER" | grep -q "production"; then
    echo "WARNING: You are running a migration procedure on a production system."
    echo ""


    RESPONSE=
    read -r -p "         Are you sure you want to continue (y)  ": RESPONSE
    if [ "$RESPONSE" != "y" ]; then
        echo "STOPPING."
        exit 1
    fi

    # check if there are any uncommited changes. It's dangerous to 
    # alter production systems when you have commits to make or changes to stash.
    if git update-index --refresh | grep -q "needs update"; then
        echo "ERROR: You have uncommited changes! Better stash your work with 'git stash'."
        exit 1
    fi

fi

export CLUSTER_PATH="$CLUSTERS_DIR/$CURRENT_CLUSTER"
CLUSTER_DEFINITION="$CLUSTER_PATH/cluster_definition"
export CLUSTER_DEFINITION="$CLUSTER_DEFINITION"

# ensure the cluster definition exists.
if [ ! -f "$CLUSTER_DEFINITION" ]; then
    echo "ERROR: The cluster definition could not be found. You may need to run 'ss-cluster'."
    echo "INFO: Consult https://www.sovereign-stack.org/clusters for more information."
    exit 1
fi

source "$CLUSTER_DEFINITION"
