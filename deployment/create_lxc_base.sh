#!/bin/bash

set -eu
cd "$(dirname "$0")"

./stub_lxc_profile.sh sovereign-stack

# create the default storage pool if necessary
if ! lxc storage list --format csv | grep -q "sovereign-stack"; then

    if [ "$DISK_TO_USE" != loop ]; then
        # we omit putting a size here so, so LXD will consume the entire disk if '/dev/sdb' or partition if '/dev/sdb1'.
        # TODO do some sanity/resource checking on DISK_TO_USE.
        lxc storage create "sovereign-stack" zfs source="$DISK_TO_USE"

    else
        # if a disk is the default 'loop', then we create a zfs storage pool 
        # on top of the existing filesystem using a loop device, per LXD docs
        lxc storage create "sovereign-stack" zfs
    fi
fi

# If our template doesn't exist, we create one.
if ! lxc image list --format csv "$VM_NAME" | grep -q "$VM_NAME"; then
    
    # If the lxc VM does exist, then we will delete it (so we can start fresh) 
    if lxc list -q --format csv | grep -q "$VM_NAME"; then
        lxc delete "$VM_NAME" --force

        # remove the ssh known endpoint else we get warnings.
        ssh-keygen -f "$SSH_HOME/known_hosts" -R "$VM_NAME"
    fi

    # let's download our base image.
    if ! lxc image list --format csv --columns l | grep -q "ubuntu-base"; then
        # if the image doesn't exist, download it from Ubuntu's image server
        # TODO see if we can fetch this file from a more censorship-resistant source, e.g., ipfs
        # we don't really need to cache this locally since it gets continually updated upstream.
        lxc image copy "images:$BASE_LXC_IMAGE" "$CLUSTER_NAME": --alias "ubuntu-base" --public --vm
    fi

    # this vm is used temperarily with 
    lxc init --profile="sovereign-stack" "ubuntu-base" "$VM_NAME" --vm

    # let's PIN the HW address for now so we don't exhaust IP
    # and so we can set DNS internally.

    # TODO move this sovereign-stack-base construction VM to separate dedicated IP
    lxc config set "$VM_NAME" "volatile.enp5s0.hwaddr=$SOVEREIGN_STACK_MAC_ADDRESS"

    lxc start "$VM_NAME"
    sleep 10

    # let's wait for the LXC vm remote machine to get an IP address.
    ./wait_for_lxc_ip.sh "$VM_NAME"
    
    # stop the VM and get a snapshot.
    lxc stop "$VM_NAME"
    lxc publish "$CLUSTER_NAME:$VM_NAME" --alias "$VM_NAME" --public
    
fi
