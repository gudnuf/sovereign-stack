#!/bin/bash

set -exu
cd "$(dirname "$0")"

./stub_lxc_profile.sh "$BASE_IMAGE_VM_NAME"

# let's download our base image.
if ! lxc image list --format csv --columns l | grep -q "$UBUNTU_BASE_IMAGE_NAME"; then
    # if the image doesn't exist, download it from Ubuntu's image server
    # TODO see if we can fetch this file from a more censorship-resistant source, e.g., ipfs
    # we don't really need to cache this locally since it gets continually updated upstream.
    lxc image copy "images:$BASE_LXC_IMAGE" "$CLUSTER_NAME": --alias "$UBUNTU_BASE_IMAGE_NAME" --public --vm --auto-update
fi

# If the lxc VM does exist, then we will delete it (so we can start fresh) 
if lxc list -q --format csv | grep -q "$BASE_IMAGE_VM_NAME"; then
    # if there's no snapshot, we dispense with the old image and try again.
    if ! lxc info "$BASE_IMAGE_VM_NAME" | grep -q "ss-docker-$LXD_UBUNTU_BASE_VERSION"; then
        lxc delete "$BASE_IMAGE_VM_NAME" --force
        ssh-keygen -f "$SSH_HOME/known_hosts" -R "$BASE_IMAGE_VM_NAME"
    fi

else
    # the base image is ubuntu:22.04.
    lxc init --profile="$BASE_IMAGE_VM_NAME" "$UBUNTU_BASE_IMAGE_NAME" "$BASE_IMAGE_VM_NAME" --vm

    # TODO move this sovereign-stack-base construction VM to separate dedicated IP
    lxc config set "$BASE_IMAGE_VM_NAME"

    lxc start "$BASE_IMAGE_VM_NAME"

    sleep 30

    # ensure the ssh service is listening at localhost
    lxc exec "$BASE_IMAGE_VM_NAME" -- wait-for-it 127.0.0.1:22 -t 120


    # stop the VM and get a snapshot.
    lxc stop "$BASE_IMAGE_VM_NAME"
    lxc snapshot "$BASE_IMAGE_VM_NAME" "ss-docker-$LXD_UBUNTU_BASE_VERSION"
fi
