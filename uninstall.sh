#!/bin/bash

set -exu

# this script uninstalls incus from the MANAGEMENT MACHINE
# if you want to remove incus from remote cluster hosts, run ss-reset.

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

# this script undoes install.sh
if ! command -v incus >/dev/null 2>&1; then
    echo "This script requires incus to be installed. Please run 'install.sh'."
    exit 1
fi

if ! incus remote get-default | grep -q "local"; then
    echo "ERROR: You MUST be on the local remote when uninstalling the SSME."
    echo "INFO: You can use 'incus remote switch local' to do this."
    exit 1
fi


if ! incus project list | grep -q "default (current)"; then
    echo "ERROR: You MUST be on the default project when uninstalling the SSME."
    echo "INFO: You can use 'incus project switch default' to do this."
    exit 1
fi


if incus list --format csv | grep -q "ss-mgmt"; then

    if incus list --format csv -q | grep -q "ss-mgmt,RUNNING"; then
        incus stop ss-mgmt
    fi

    if incus config device list ss-mgmt -q | grep -q "ss-code"; then
        incus config device remove ss-mgmt ss-code
    fi

    if incus config device list ss-mgmt -q | grep -q "ss-root"; then
        incus config device remove ss-mgmt ss-root
    fi

    if incus config device list ss-mgmt -q | grep -q "ss-ssh"; then
        incus config device remove ss-mgmt ss-ssh
    fi

    incus delete ss-mgmt
fi

if [ "$PURGE_INCUS" = true ]; then

    if incus profile device list default | grep -q root; then
        incus profile device remove default root
    fi

    if incus profile device list default | grep -q enp5s0; then
        incus profile device remove default enp5s0
    fi

    if incus network list --project default | grep -q incusbr0; then
        incus network delete incusbr0
    fi

    # this file contains the BASE_IMAGE_NAME
    . ./deployment/base.sh
    if incus image list | grep -q "$UBUNTU_BASE_IMAGE_NAME"; then
        incus image delete "$UBUNTU_BASE_IMAGE_NAME"
    fi

    if incus storage list --format csv | grep -q sovereign-stack; then
        incus storage delete sovereign-stack
    fi

    if dpkg -l | grep -q incus; then
        sudo apt purge incus -y
    fi

fi