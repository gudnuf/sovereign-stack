#!/bin/bash

set -exu

# this script undoes install.sh
if ! command -v lxc >/dev/null 2>&1; then
    echo "This script requires 'lxc' to be installed. Please run 'install.sh'."
    exit 1
fi

. ./defaults.sh

if lxc list --format csv | grep -q ss-mgmt; then

    if ! lxc list --format csv | grep ss-mgmt | grep -q "RUNNING"; then
        lxc stop ss-mgmt
    fi

    lxc config device remove ss-mgmt sscode
    lxc delete ss-mgmt -f
fi

if lxc profile device list default | grep -q root; then
    lxc profile device remove default root
fi

if lxc profile device list default | grep -q enp5s0; then
    lxc profile device remove default enp5s0
fi

if lxc network list | grep -q lxdbr0; then
    lxc network delete lxdbr0
fi

if lxc image list | grep -q "$UBUNTU_BASE_IMAGE_NAME"; then
    lxc image delete "$UBUNTU_BASE_IMAGE_NAME"
fi

if lxc storage list --format csv | grep -q sovereign-stack; then
    lxc storage delete sovereign-stack
fi

if snap list | grep -q lxd; then
    sudo snap remove lxd
    sleep 2
fi

if zfs list | grep -q sovereign-stack; then
    sudo zfs destroy -r sovereign-stack
fi

if zfs list | grep -q "sovereign-stack"; then
    sudo zfs destroy -r "rpool/lxd"
fi
