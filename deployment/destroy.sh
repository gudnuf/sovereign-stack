#!/bin/bash

set -ex
cd "$(dirname "$0")"
# this script takes down all resources in the cluster. This script is DESTRUCTIVE of data, so make sure it's backed up first.


if lxc remote get-default | grep -q "local"; then
    echo "ERROR: you are on the local lxc remote. Nothing to destroy"
    exit 1
fi

RESPONSE=
read -r -p "Are you sure you want to continue? Responding 'y' here results in destruction of user data!": RESPONSE
if [ "$RESPONSE" != "y" ]; then
    echo "STOPPING."
    exit 0
fi

. ../defaults.sh

. ./cluster_env.sh

. ./project_env.sh

for VM in www btcpayserver; do
    LXD_NAME="$VM-${DOMAIN_NAME//./-}"

    if lxc list | grep -q "$LXD_NAME"; then
        lxc delete -f "$LXD_NAME"

        # remove the ssh known endpoint else we get warnings.
        ssh-keygen -f "$SSH_HOME/known_hosts" -R "$LXD_NAME"
    fi

    if lxc profile list | grep -q "$LXD_NAME"; then
        lxc profile delete "$LXD_NAME"
    fi
done


# delete the base image so it can be created.
if lxc list | grep -q "$BASE_IMAGE_VM_NAME"; then
    lxc delete -f "$BASE_IMAGE_VM_NAME"
    # remove the ssh known endpoint else we get warnings.
    ssh-keygen -f "$SSH_HOME/known_hosts" -R "$LXD_NAME"
fi
