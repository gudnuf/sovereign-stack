#!/bin/bash

set -eu
cd "$(dirname "$0")"

CURRENT_CLUSTER="$(lxc remote get-default)"

if echo "$CURRENT_CLUSTER" | grep -q "production"; then
    echo "ERROR: YOU MUST COMMENT THIS OUT BEFORE YOU CAN RUN MIGRATE ON PROUDCTION/."
    exit 1
fi

source ./defaults.sh

export CLUSTER_PATH="$CLUSTERS_DIR/$CURRENT_CLUSTER"
CLUSTER_DEFINITION="$CLUSTER_PATH/cluster_definition"
export CLUSTER_DEFINITION="$CLUSTER_DEFINITION"

# ensure the cluster definition exists.
if [ ! -f "$CLUSTER_DEFINITION" ]; then
    echo "ERROR: The cluster definition could not be found. You may need to re-run 'ss-cluster create'."
    exit 1
fi

source "$CLUSTER_DEFINITION"

# source project defition.
# Now let's load the project definition.
PROJECT_PATH="$PROJECTS_DIR/$PROJECT_NAME"
PROJECT_DEFINITION_PATH="$PROJECT_PATH/project_definition"
source "$PROJECT_DEFINITION_PATH"

export PRIMARY_SITE_DEFINITION_PATH="$SITES_PATH/$PRIMARY_DOMAIN/site_definition"
source "$PRIMARY_SITE_DEFINITION_PATH"

# Check to see if any of the VMs actually don't exist. 
# (we only migrate instantiated vms)
for VM in www btcpayserver; do
    LXD_NAME="$VM-${DOMAIN_NAME//./-}"

    # if the VM doesn't exist, the we emit an error message and hard quit.
    if ! lxc list --format csv | grep -q "$LXD_NAME"; then
        echo "ERROR: there is no VM named '$LXD_NAME'. You probably need to run ss-deploy again."
        exit 1
    fi
done

BTCPAY_RESTORE_ARCHIVE_PATH="$SITES_PATH/$PRIMARY_DOMAIN/backups/btcpayserver/$(date +%s).tar.gz"
echo "INFO: The BTCPAY_RESTORE_ARCHIVE_PATH for this migration will be: $BTCPAY_RESTORE_ARCHIVE_PATH" 

# first we run ss-deploy --stop
# this grabs a backup of all data (backups are on by default) and saves them to the management machine
# the --stop flag ensures that services do NOT come back online.
# by default, we grab a backup. 

bash -c "./deploy.sh --stop --backup-archive-path=$BTCPAY_RESTORE_ARCHIVE_PATH"

RESPONSE=
read -r -p "Are you sure you want to continue the migration? We have a backup TODO.": RESPONSE
if [ "$RESPONSE" != "y" ]; then
    echo "STOPPING."
    exit 0
fi


for VM in www btcpayserver; do
    LXD_NAME="$VM-${DOMAIN_NAME//./-}"
    lxc delete -f "$LXD_NAME"

    lxc profile delete "$LXD_NAME"
done


# delete the base image so it can be created.
if lxc list | grep -q sovereign-stack-base; then
    lxc delete -f sovereign-stack-base
fi

# these only get initialzed upon creation, so we MUST delete here so they get recreated.
if lxc profile list | grep -q sovereign-stack; then
    lxc profile delete sovereign-stack
fi

if lxc image list | grep -q "sovereign-stack-base"; then
    lxc image rm sovereign-stack-base
fi

# Then we can run a restore operation and specify the backup archive at the CLI.
bash -c "./deploy.sh -y --restore-www --restore-btcpay --backup-archive-path=$BTCPAY_RESTORE_ARCHIVE_PATH"
