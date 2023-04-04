#!/bin/bash


set -e
cd "$(dirname "$0")"


PURGE_LXD=false

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --purge)
            PURGE_LXD=true
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

source ../defaults.sh

./down.sh

# these only get initialzed upon creation, so we MUST delete here so they get recreated.
if lxc profile list | grep -q "$BASE_IMAGE_VM_NAME"; then
    lxc profile delete "$BASE_IMAGE_VM_NAME"
fi

if lxc image list | grep -q "$BASE_IMAGE_VM_NAME"; then
    lxc image rm "$BASE_IMAGE_VM_NAME"
fi

if lxc image list | grep -q "$DOCKER_BASE_IMAGE_NAME"; then
    lxc image rm "$DOCKER_BASE_IMAGE_NAME"
fi

CURRENT_PROJECT="$(lxc info | grep "project:" | awk '{print $2}')"
if ! lxc info | grep -q "project: default"; then
    lxc project switch default
    lxc project delete "$CURRENT_PROJECT"
fi


if [ "$PURGE_LXD" = true ]; then

    if lxc profile show default | grep -q "root:"; then
        lxc profile device remove default root
    fi

    if lxc profile show default| grep -q "eth0:"; then
        lxc profile device remove default eth0
    fi

    if lxc network list --format csv -q --project default | grep -q lxdbr0; then
        lxc network delete lxdbr0 --project default
    fi

    if lxc network list --format csv -q --project default | grep -q lxdbr1; then
        lxc network delete lxdbr1 --project default
    fi

    # # create the testnet/mainnet blocks/chainstate subvolumes.
    # for CHAIN in mainnet testnet; do
    #     for DATA in blocks chainstate; do
    #         if lxc storage volume list ss-base | grep -q "$CHAIN-$DATA"; then
    #             lxc storage volume delete ss-base "$CHAIN-$DATA"
    #         fi
    #     done
    # done

    if lxc storage list --format csv | grep -q ss-base; then
        lxc storage delete ss-base
    fi

    CURRENT_REMOTE="$(lxc remote get-default)"
    if ! lxc remote get-default | grep -q "local"; then
        lxc remote switch local
        lxc remote remove "$CURRENT_REMOTE"

        echo "INFO: The remote '$CURRENT_REMOTE' has been removed! You are now controlling your local instance."
    fi
fi