#!/bin/bash

set -x

SSH_ENDPOINT_HOSTNAME="atlantis"
SSH_ENDPOINT_DOMAIN_NAME="ancapistan.io"
TEST_DOMAIN="ancapistan.casa"
CLUSTER_NAME="development"

export LXD_VM_NAME="${TEST_DOMAIN//./-}"

if [ -n "$TEST_DOMAIN" ]; then
    lxc delete --force www-"$LXD_VM_NAME"
    lxc delete --force btcpay-"$LXD_VM_NAME"
    lxc delete --force sovereign-stack
    lxc delete --force sovereign-stack-base

    lxc profile delete www-"$LXD_VM_NAME"
    lxc profile delete btcpay-"$LXD_VM_NAME"
fi

lxc profile delete sovereign-stack

lxc image rm sovereign-stack-base
lxc image rm ubuntu-base

lxc network delete lxdbrSS

lxc storage delete sovereign-stack

lxc remote switch "local"
lxc remote remove "$CLUSTER_NAME"

source "$HOME/.bashrc"

./cluster.sh create "$CLUSTER_NAME" "$SSH_ENDPOINT_HOSTNAME.$SSH_ENDPOINT_DOMAIN_NAME" 
#--data-plane-interface=enp89s0

#./deploy.sh
