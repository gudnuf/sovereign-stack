#!/bin/bash

set -exu
cd "$(dirname "$0")"

. ./base.sh

bash -c "./stub_lxc_profile.sh --lxd-hostname=$BASE_IMAGE_VM_NAME"

if lxc list -q --project default | grep -q "$BASE_IMAGE_VM_NAME" ; then
    lxc delete -f "$BASE_IMAGE_VM_NAME" --project=default
fi

# let's download our base image.
if ! lxc image list --format csv --columns l | grep -q "$UBUNTU_BASE_IMAGE_NAME"; then
    # copy the image down from canonical.
    lxc image copy "images:$BASE_LXC_IMAGE" "$REMOTE_NAME": --alias "$UBUNTU_BASE_IMAGE_NAME" --public --vm --auto-update
fi

# If the lxc VM does exist, then we will delete it (so we can start fresh) 
if lxc list --format csv -q | grep -q "$UBUNTU_BASE_IMAGE_NAME"; then
    # if there's no snapshot, we dispense with the old image and try again.
    if ! lxc info "$BASE_IMAGE_VM_NAME" | grep -q "$UBUNTU_BASE_IMAGE_NAME"; then
        lxc delete "$BASE_IMAGE_VM_NAME" --force
        ssh-keygen -f "$SSH_HOME/known_hosts" -R "$BASE_IMAGE_VM_NAME"
    fi
else
    # the base image is ubuntu:22.04.
    lxc init --profile="$BASE_IMAGE_VM_NAME" "$UBUNTU_BASE_IMAGE_NAME" "$BASE_IMAGE_VM_NAME" --vm --project=default

    # TODO move this sovereign-stack-base construction VM to separate dedicated IP
    lxc config set "$BASE_IMAGE_VM_NAME" --project=default

    # for CHAIN in mainnet testnet; do
    #     for DATA in blocks chainstate; do
    #         lxc storage volume attach ss-base "$CHAIN-$DATA" "$BASE_IMAGE_VM_NAME" "/home/ubuntu/bitcoin/$DATA"
    #     done
    # done

    lxc start "$BASE_IMAGE_VM_NAME" --project=default

    sleep 15
    while lxc exec "$BASE_IMAGE_VM_NAME" --project=default -- [ ! -f /var/lib/cloud/instance/boot-finished ]; do
        sleep 1
    done

    # ensure the ssh service is listening at localhost
    lxc exec "$BASE_IMAGE_VM_NAME" --project=default -- wait-for-it -t 100 127.0.0.1:22

    # # If we have any chaninstate or blocks in our SSME, let's push them to the
    # # remote host as a zfs volume that way deployments can share a common history
    # # of chainstate/blocks.
    # for CHAIN in testnet mainnet; do
    #     for DATA in blocks chainstate; do
    #         # if the storage snapshot doesn't yet exist, create it.
    #         if ! lxc storage volume list ss-base -q --format csv -c n | grep -q "$CHAIN-$DATA/snap0"; then
    #             DATA_PATH="/home/ubuntu/.ss/cache/bitcoin/$CHAIN/$DATA"
    #             if [ -d "$DATA_PATH" ]; then
    #                 COMPLETE_FILE_PATH="$DATA_PATH/complete"
    #                 if lxc exec "$BASE_IMAGE_VM_NAME" -- [ ! -f "$COMPLETE_FILE_PATH" ]; then
    #                     lxc file push --recursive --project=default "$DATA_PATH/" "$BASE_IMAGE_VM_NAME""$DATA_PATH/"
    #                     lxc exec "$BASE_IMAGE_VM_NAME" -- su ubuntu - bash -c "echo $(date) > $COMPLETE_FILE_PATH"
    #                     lxc exec "$BASE_IMAGE_VM_NAME" -- chown -R 999:999 "$DATA_PATH/$DATA"
    #                 else
    #                     echo "INFO: it appears as though $CHAIN/$DATA has already been initialized. Continuing."
    #                 fi
    #             fi
    #         fi
    #     done
    # done

    # stop the VM and get a snapshot.
    lxc stop "$BASE_IMAGE_VM_NAME" --project=default
    lxc snapshot "$BASE_IMAGE_VM_NAME" "$UBUNTU_BASE_IMAGE_NAME" --project=default

fi

echo "INFO: Publishing '$BASE_IMAGE_VM_NAME' as image '$DOCKER_BASE_IMAGE_NAME'. Please wait."
lxc publish --public "$BASE_IMAGE_VM_NAME/$UBUNTU_BASE_IMAGE_NAME" --project=default --alias="$DOCKER_BASE_IMAGE_NAME" --compression none

echo "INFO: Success creating the base image. Deleting artifacts from the build process."
lxc delete -f "$BASE_IMAGE_VM_NAME" --project=default

# # now let's get a snapshot of each of the blocks/chainstate directories.
# for CHAIN in testnet mainnet; do
#     for DATA in blocks chainstate; do
#         if ! lxc storage volume list ss-base -q --format csv -c n | grep -q "$CHAIN-$DATA/snap0"; then
#             echo "INFO: Creating a snapshot 'ss-base/$CHAIN-$DATA/snap0'."
#             lxc storage volume snapshot ss-base --project=default "$CHAIN-$DATA"
#         fi
#     done
# done
