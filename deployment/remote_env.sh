#!/bin/bash

set -eu

CURRENT_REMOTE="$(lxc remote get-default)"

if echo "$CURRENT_REMOTE" | grep -q "production"; then
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

. ./deployment_defaults.sh

export REMOTE_PATH="$REMOTES_PATH/$CURRENT_REMOTE"
REMOTE_DEFINITION="$REMOTE_PATH/remote.conf"
export REMOTE_DEFINITION="$REMOTE_DEFINITION"

# ensure the remote definition exists.
if [ ! -f "$REMOTE_DEFINITION" ]; then
    echo "ERROR: The remote definition could not be found. You may need to run 'ss-remote'."
    echo "INFO: Consult https://www.sovereign-stack.org/ss-remote for more information."
    exit 1
fi

source "$REMOTE_DEFINITION"

# ensure our projects are provisioned according to DEPLOYMENT_STRING
for PROJECT_CHAIN in ${DEPLOYMENT_STRING//,/ }; do
    NO_PARENS="${PROJECT_CHAIN:1:${#PROJECT_CHAIN}-2}"
    PROJECT_PREFIX=$(echo "$NO_PARENS" | cut -d'|' -f1)
    BITCOIN_CHAIN=$(echo "$NO_PARENS" | cut -d'|' -f2)
    PROJECT_NAME="$PROJECT_PREFIX-$BITCOIN_CHAIN"

    # create the lxc project as specified by PROJECT_NAME
    if ! lxc project list | grep -q "$PROJECT_NAME"; then
        lxc project create "$PROJECT_NAME"
        lxc project set "$PROJECT_NAME" features.networks=true features.images=false features.storage.volumes=true
        lxc project switch "$PROJECT_NAME"
    fi

    # default values are already at regtest mode.
    if [ "$BITCOIN_CHAIN" = testnet ]; then

        WWW_SSDATA_DISK_SIZE_GB=30
        WWW_BACKUP_DISK_SIZE_GB=30
        WWW_DOCKER_DISK_SIZE_GB=50

        BTCPAYSERVER_SSDATA_DISK_SIZE_GB=30
        BTCPAYSERVER_BACKUP_DISK_SIZE_GB=30
        BTCPAYSERVER_DOCKER_DISK_SIZE_GB=100

    elif [ "$BITCOIN_CHAIN" = mainnet ]; then
        
        WWW_SSDATA_DISK_SIZE_GB=40
        WWW_BACKUP_DISK_SIZE_GB=40
        WWW_DOCKER_DISK_SIZE_GB=1000

        BTCPAYSERVER_SSDATA_DISK_SIZE_GB=30
        BTCPAYSERVER_BACKUP_DISK_SIZE_GB=30
        BTCPAYSERVER_DOCKER_DISK_SIZE_GB=500

    fi

    export WWW_SSDATA_DISK_SIZE_GB="$WWW_SSDATA_DISK_SIZE_GB"
    export WWW_BACKUP_DISK_SIZE_GB="$WWW_BACKUP_DISK_SIZE_GB"
    export WWW_DOCKER_DISK_SIZE_GB="$WWW_DOCKER_DISK_SIZE_GB"

    export BTCPAYSERVER_SSDATA_DISK_SIZE_GB="$BTCPAYSERVER_SSDATA_DISK_SIZE_GB"
    export BTCPAYSERVER_BACKUP_DISK_SIZE_GB="$BTCPAYSERVER_BACKUP_DISK_SIZE_GB"
    export BTCPAYSERVER_DOCKER_DISK_SIZE_GB="$BTCPAYSERVER_DOCKER_DISK_SIZE_GB"

done