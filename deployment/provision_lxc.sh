#!/bin/bash

set -eu
cd "$(dirname "$0")"

./stub_lxc_profile.sh "$LXD_VM_NAME"

# now let's create a new VM to work with.
lxc init --profile="$LXD_VM_NAME" "$VM_NAME" "$LXD_VM_NAME" --vm

# let's PIN the HW address for now so we don't exhaust IP
# and so we can set DNS internally.
lxc config set "$LXD_VM_NAME" "volatile.enp5s0.hwaddr=$MAC_ADDRESS_TO_PROVISION"
lxc config device override "$LXD_VM_NAME" root size="${ROOT_DISK_SIZE_GB}GB"

lxc start "$LXD_VM_NAME"

./wait_for_lxc_ip.sh "$LXD_VM_NAME"
