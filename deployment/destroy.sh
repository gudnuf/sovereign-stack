#!/bin/bash

set -e
cd "$(dirname "$0")"

# this script destroys all resources in the current project.

if lxc remote get-default | grep -q "local"; then
    echo "ERROR: you are on the local lxc remote. Nothing to destroy"
    exit 1
fi

USER_TARGET_PROJECT=

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --project=*)
            USER_TARGET_PROJECT="${i#*=}"
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

    if ! lxc info | grep "project:" | grep -q "$PROJECT_NAME"; then
        if lxc project list | grep -q "$PROJECT_NAME"; then
            lxc project switch "$PROJECT_NAME"
        fi
    fi

    for VIRTUAL_MACHINE in www btcpayserver; do
        LXD_NAME="$VIRTUAL_MACHINE-${PRIMARY_DOMAIN//./-}"

        if lxc list | grep -q "$LXD_NAME"; then
            lxc delete -f "$LXD_NAME"

            # remove the ssh known endpoint else we get warnings.
            ssh-keygen -f "$SSH_HOME/known_hosts" -R "$LXD_NAME"
        fi

        if lxc profile list | grep -q "$LXD_NAME"; then
            lxc profile delete "$LXD_NAME"
        fi

        # destroy the docker volume
        VM_ID=w
        if [ "$VIRTUAL_MACHINE" = btcpayserver ]; then
            VM_ID="b"
        fi

        RESPONSE=
        read -r -p "Do you want to delete the docker volume for '$LXD_NAME'?": RESPONSE
        if [ "$RESPONSE" = "y" ]; then
            VOLUME_NAME="$PRIMARY_DOMAIN_IDENTIFIER-$VM_ID"
            if lxc storage volume list ss-base | grep -q "$VOLUME_NAME"; then
                lxc storage volume delete ss-base "$VOLUME_NAME"
            fi
        else
            echo "INFO: User DID NOT select 'y'. The storage volume will remain."
        fi

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
