#!/bin/bash

set -e

INCUS_INSTANCE_NAME=

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --incus-name=*)
            INCUS_INSTANCE_NAME="${i#*=}"
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

# if the invoker did not set the instance name, throw an error.
if [ -z "$INCUS_INSTANCE_NAME" ]; then
    echo "ERROR: The instance name was not specified. Use '--incus-name' when calling wait_for_ip.sh."
    exit 1
fi

if ! incus list --format csv | grep -q "$INCUS_INSTANCE_NAME"; then
    echo "ERROR: the instance '$INCUS_INSTANCE_NAME' does not exist."
    exit 1
fi

IP_V4_ADDRESS=
while true; do
    IP_V4_ADDRESS="$(incus list "$INCUS_INSTANCE_NAME" --format csv --columns=4 | grep enp5s0 | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')" || true
    export IP_V4_ADDRESS="$IP_V4_ADDRESS"
    if [ -n "$IP_V4_ADDRESS" ]; then
        # give the machine extra time to spin up.
        wait-for-it -t 300 "$IP_V4_ADDRESS:22"
        break
    else
        sleep 1
        printf '.'
    fi
done

# wait for cloud-init to complet before returning.
while incus exec "$INCUS_INSTANCE_NAME" -- [ ! -f /var/lib/cloud/instance/boot-finished ]; do
    sleep 1
done

sleep 1