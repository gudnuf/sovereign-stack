#!/bin/bash

set -e

IP_V4_ADDRESS=
while true; do
    # wait for 
    if lxc list ss-mgmt | grep -q enp5s0; then
        break;
    else
        sleep 1
    fi
done

while true; do
    IP_V4_ADDRESS=$(lxc list ss-mgmt --format csv --columns=4 | grep enp5s0 | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
    if [ -n "$IP_V4_ADDRESS" ]; then
        # give the machine extra time to spin up.
        break;
    else
        sleep 1
        printf '.'
    fi
done


export IP_V4_ADDRESS="$IP_V4_ADDRESS"
