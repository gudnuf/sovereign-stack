#!/bin/bash

set -e

LXC_INSTANCE_NAME="$1"
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

# Let's remove any entry in our known_hosts, then add it back.
# we are using IP address here so we don't have to rely on external DNS 
# configuration for the base image preparataion.
ssh-keygen -R "$IP_V4_ADDRESS"

ssh-keyscan -H -t ecdsa "$IP_V4_ADDRESS" >> "$SSH_HOME/known_hosts"

ssh "ubuntu@$IP_V4_ADDRESS" sudo chown -R ubuntu:ubuntu /home/ubuntu
