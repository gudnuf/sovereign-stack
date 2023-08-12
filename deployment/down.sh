#!/bin/bash

# https://www.sovereign-stack.org/ss-down/

set -eu
cd "$(dirname "$0")"

if lxc remote get-default -q | grep -q "local"; then
    echo "ERROR: you are on the local lxc remote. Nothing to take down"
    exit 1
fi

KEEP_DOCKER_VOLUME=true
OTHER_SITES_LIST=
SKIP_BTCPAYSERVER=false
SKIP_WWW=false
SKIP_CLAMSSERVER=false

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --purge)
            KEEP_DOCKER_VOLUME=false
            shift
        ;;
        --skip-btcpayserver)
            SKIP_BTCPAYSERVER=true
            shift
        ;;
        --skip-wwwserver)
            SKIP_WWW=true
            shift
        ;;
        --skip-clamsserver)
            SKIP_CLAMSSERVER=true
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

SERVERS=
if [ "$SKIP_BTCPAYSERVER" = false ]; then
    SERVERS="btcpayserver"
fi

if [ "$SKIP_WWW" = false ]; then
    SERVERS="www $SERVERS"
fi

if [ "$SKIP_CLAMSSERVER" = false ]; then
    SERVERS="clamsserver $SERVERS"
fi

. ./deployment_defaults.sh

. ./remote_env.sh

. ./project_env.sh

# let's bring down services on the remote deployment if necessary.
export DOMAIN_NAME="$PRIMARY_DOMAIN"
export SITE_PATH="$SITES_PATH/$PRIMARY_DOMAIN"

source "$SITE_PATH/site.conf"
source ./project/domain_env.sh

source ./domain_list.sh

for VIRTUAL_MACHINE in $SERVERS; do

    LXD_NAME="$VIRTUAL_MACHINE-${PRIMARY_DOMAIN//./-}"

    if lxc list | grep -q "$LXD_NAME"; then
        bash -c "./stop.sh --server=$VIRTUAL_MACHINE"

        lxc stop "$LXD_NAME"

        lxc delete "$LXD_NAME"
    fi

    # remove the ssh known endpoint else we get warnings.
    ssh-keygen -f "$SSH_HOME/known_hosts" -R "$VIRTUAL_MACHINE.$PRIMARY_DOMAIN" | exit

    if lxc profile list | grep -q "$LXD_NAME"; then
        lxc profile delete "$LXD_NAME"
    fi

    if [ "$KEEP_DOCKER_VOLUME" = false ]; then
        # destroy the docker volume
        VM_ID=w
        if [ "$VIRTUAL_MACHINE" = btcpayserver ]; then
            VM_ID="b"
        elif [ "$VIRTUAL_MACHINE" = clamsserver ]; then
            VM_ID="c"
        fi

        # d for docker; b for backup; s for ss-data
        for DATA in d b s; do
            VOLUME_NAME="$PRIMARY_DOMAIN_IDENTIFIER-$VM_ID""$DATA"
            if lxc storage volume list ss-base -q | grep -q "$VOLUME_NAME"; then
                RESPONSE=
                read -r -p "Are you sure you want to delete the '$VOLUME_NAME' volume intended for '$LXD_NAME'?": RESPONSE
            
                if [ "$RESPONSE" = "y" ]; then
                    lxc storage volume delete ss-base "$VOLUME_NAME"
                fi
            fi
        done
    else
        # we maintain the volumes
        # TODO make a snapshot on all the zfs storage volumes.
        echo "TODO: create snapshot of ZFS volumes and pull them to mgmt machine."
    fi
done

if lxc network list -q | grep -q ss-ovn; then
    lxc network delete ss-ovn
fi