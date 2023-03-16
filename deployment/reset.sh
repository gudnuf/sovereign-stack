#!/bin/bash


set -e
cd "$(dirname "$0")"

source ../defaults.sh

./destroy.sh

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

if lxc profile show default | grep -q "root:"; then
    lxc profile device remove default root
fi

if lxc profile show default| grep -q "eth0:"; then
    lxc profile device remove default eth0
fi

if lxc network list --format csv | grep -q lxdbr0; then
    lxc network delete lxdbr0
fi

if lxc network list --format csv | grep -q lxdbr1; then
    lxc network delete lxdbr1
fi


# create the testnet/mainnet blocks/chainstate subvolumes.
for CHAIN in mainnet testnet; do
    for DATA in blocks chainstate; do
        if lxc storage volume list ss-base | grep -q "$CHAIN-$DATA"; then
            lxc storage volume delete ss-base "$CHAIN-$DATA"
        fi
    done
done


if lxc storage list --format csv | grep -q ss-base; then
    lxc storage delete ss-base
fi


CURRENT_REMOTE="$(lxc remote get-default)"
if ! lxc remote get-default | grep -q "local"; then
    lxc remote switch local
    lxc remote remove "$CURRENT_REMOTE"
fi