#!/bin/bash

set -eu
cd "$(dirname "$0")"

. ../defaults.sh

. ./remote_env.sh


echo "Global Settings:"

lxc image list
lxc storage list
lxc storage volume list ss-base

echo
echo

for PROJECT_CHAIN in ${DEPLOYMENT_STRING//,/ }; do
    NO_PARENS="${PROJECT_CHAIN:1:${#PROJECT_CHAIN}-2}"
    PROJECT_PREFIX=$(echo "$NO_PARENS" | cut -d'|' -f1)
    BITCOIN_CHAIN=$(echo "$NO_PARENS" | cut -d'|' -f2)
    PROJECT_NAME="$PROJECT_PREFIX-$BITCOIN_CHAIN"

    echo
    echo
    echo "Project: $PROJECT_NAME"
    echo "----------------------"
    if ! lxc info | grep "project:" | grep -q "$PROJECT_NAME"; then
        if lxc project list | grep -q "$PROJECT_NAME"; then
            lxc project switch "$PROJECT_NAME"
        fi
    fi

    echo
    echo "  Networks:"
    lxc network list
    echo
    echo "  Profiles:"
    lxc profile list
    echo
    echo "  Instances (VMs):"
    lxc list
    echo

done