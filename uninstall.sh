#!/bin/bash

set -exu

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

# this script undoes install.sh
if ! command -v lxc >/dev/null 2>&1; then
    echo "This script requires 'lxc' to be installed. Please run 'install.sh'."
    exit 1
fi

. ./defaults.sh

if lxc list --format csv | grep -q "ss-mgmt"; then

    if lxc list --format csv -q | grep -q "ss-mgmt,RUNNING"; then
        lxc stop ss-mgmt
    fi

    lxc config device remove ss-mgmt sscode

    if [ -d "$SS_ROOT_PATH" ]; then
        lxc config device remove ss-mgmt ssroot
    fi

    if [ -d "$HOME/.ssh" ]; then
        lxc config device remove ss-mgmt ss-ssh
    fi

    lxc delete ss-mgmt
fi

if [ "$PURGE_LXD" = true ]; then

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
    fi
fi