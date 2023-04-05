#!/bin/bash

# https://www.sovereign-stack.org/ss-down/

set -exu
cd "$(dirname "$0")"

if lxc remote get-default -q | grep -q "local"; then
    echo "ERROR: you are on the local lxc remote. Nothing to take down"
    exit 1
fi

KEEP_DOCKER_VOLUME=true

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --destroy)
            KEEP_DOCKER_VOLUME=false
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

. ../defaults.sh

. ./remote_env.sh

. ./project_env.sh


# let's bring down services on the remote deployment if necessary.
export DOMAIN_NAME="$PRIMARY_DOMAIN"
export SITE_PATH="$SITES_PATH/$PRIMARY_DOMAIN"

source "$SITE_PATH/site.conf"
source ./project/domain_env.sh

SKIP=btcpayserver
for VIRTUAL_MACHINE in www btcpayserver; do
    LXD_NAME="$VIRTUAL_MACHINE-${PRIMARY_DOMAIN//./-}"

    if lxc list | grep -q "$LXD_NAME"; then
        bash -c "./project/deploy.sh --stop --skip-$SKIP"

        lxc stop "$LXD_NAME"

        lxc delete "$LXD_NAME"

        # remove the ssh known endpoint else we get warnings.
        ssh-keygen -f "$SSH_HOME/known_hosts" -R "$LXD_NAME"
    fi

    if lxc profile list | grep -q "$LXD_NAME"; then
        lxc profile delete "$LXD_NAME"
    fi

    if [ "$KEEP_DOCKER_VOLUME" = false ]; then
        # destroy the docker volume
        VM_ID=w
        if [ "$VIRTUAL_MACHINE" = btcpayserver ]; then
            VM_ID="b"
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
    fi

    SKIP=www
done

if lxc network list -q | grep -q ss-ovn; then
    lxc network delete ss-ovn
fi

# delete the base image so it can be created.
if lxc list | grep -q "$BASE_IMAGE_VM_NAME"; then
    lxc delete -f "$BASE_IMAGE_VM_NAME" --project default
    # remove the ssh known endpoint else we get warnings.
    ssh-keygen -f "$SSH_HOME/known_hosts" -R "$BASE_IMAGE_VM_NAME"
fi
