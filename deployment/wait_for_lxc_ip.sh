#!/bin/bash

set -ex

LXC_INSTANCE_NAME=

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --lxc-name=*)
            LXC_INSTANCE_NAME="${i#*=}"
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

# if the invoker did not set the instance name, throw an error.
if [ -z "$LXC_INSTANCE_NAME" ]; then
    echo "ERROR: The lxc instance name was not specified. Use '--lxc-name' when calling wait_for_lxc_ip.sh."
    exit 1
fi

if ! lxc list --format csv | grep -q "$LXC_INSTANCE_NAME"; then
    echo "ERROR: the lxc instance '$LXC_INSTANCE_NAME' does not exist."
    exit 1
fi

IP_V4_ADDRESS=
while true; do
    IP_V4_ADDRESS="$(lxc list "$LXC_INSTANCE_NAME" --format csv --columns=4 | grep enp5s0 | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')" || true
    export IP_V4_ADDRESS="$IP_V4_ADDRESS"
    if [ -n "$IP_V4_ADDRESS" ]; then
        # give the machine extra time to spin up.
        wait-for-it -t 300 "$IP_V4_ADDRESS:22"
        echo ""
        break
    else
        sleep 1
        printf '.'
    fi
done
