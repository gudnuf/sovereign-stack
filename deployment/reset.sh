#!/bin/bash


set -e
cd "$(dirname "$0")"

PURGE_INCUS=false

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --purge)
            PURGE_INCUS=true
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
if incus profile list | grep -q "$BASE_IMAGE_VM_NAME"; then
    incus profile delete "$BASE_IMAGE_VM_NAME"
fi

if incus image list | grep -q "$BASE_IMAGE_VM_NAME"; then
    incus image rm "$BASE_IMAGE_VM_NAME"
fi

if incus image list | grep -q "$DOCKER_BASE_IMAGE_NAME"; then
    incus image rm "$DOCKER_BASE_IMAGE_NAME"
fi

CURRENT_PROJECT="$(incus info | grep "project:" | awk '{print $2}')"
if ! incus info | grep -q "project: default"; then
    incus project switch default
    incus project delete "$CURRENT_PROJECT"
fi


if [ "$PURGE_INCUS" = true ]; then

    if incus profile show default | grep -q "root:"; then
        incus profile device remove default root
    fi

    if incus profile show default| grep -q "eth0:"; then
        incus profile device remove default eth0
    fi

    if incus network list --format csv -q --project default | grep -q incusbr0; then
        incus network delete incusbr0 --project default
    fi

    if incus network list --format csv -q --project default | grep -q lxdbr1; then
        incus network delete lxdbr1 --project default
    fi

    # # create the testnet/mainnet blocks/chainstate subvolumes.
    # for CHAIN in mainnet testnet; do
    #     for DATA in blocks chainstate; do
    #         if incus storage volume list ss-base | grep -q "$CHAIN-$DATA"; then
    #             incus storage volume delete ss-base "$CHAIN-$DATA"
    #         fi
    #     done
    # done

    echo "WARNING: ss-basae NOT DELETED. NEED TO TEST THIS SCRIPT"
    # if incus storage list --format csv | grep -q ss-base; then
    #     incus storage delete ss-base
    # fi

    CURRENT_REMOTE="$(incus remote get-default)"
    if ! incus remote get-default | grep -q "local"; then
        incus remote switch local
        incus remote remove "$CURRENT_REMOTE"

        echo "INFO: The remote '$CURRENT_REMOTE' has been removed! You are now controlling your local instance."
    fi
fi