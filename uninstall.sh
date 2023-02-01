#!/bin/bash

set -exu

# this script undoes install.sh

. ./defaults.sh

if lxc list --format csv | grep -q ss-mgmt; then

    if ! list list --format csv | grep ss-mgmt | grep -q "RUNNING"; then
        lxc stop ss-mgmt
    fi

    lxc config device remove ss-mgmt sscode
    lxc delete ss-mgmt
fi

# if lxc image list | grep -q "$UBUNTU_BASE_IMAGE_NAME"; then
#     lxc image delete "$UBUNTU_BASE_IMAGE_NAME"
# fi

# if lxc storage list --format csv | grep -q sovereign-stack; then
#     lxc profile device remove default root
#     lxc storage delete sovereign-stack
# fi

# if snap list | grep -q lxd; then
#     sudo snap remove lxd
#     sleep 2
# fi

# if zfs list | grep -q sovereign-stack; then
#     sudo zfs destroy -r sovereign-stack
# fi

# if zfs list | grep -q "sovereign-stack"; then
#     sudo zfs destroy -r "rpool/lxd"
# fi
