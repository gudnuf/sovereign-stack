#!/bin/bash

set -x

CLUSTER_NAME=""
SSH_ENDPOINT_HOSTNAME=""
SSH_ENDPOINT_DOMAIN_NAME=""
TEST_DOMAIN=""

export LXD_VM_NAME="${TEST_DOMAIN//./-}"

lxc delete --force www-"$LXD_VM_NAME"
lxc delete --force btcpay-"$LXD_VM_NAME"
lxc delete --force sovereign-stack
lxc delete --force sovereign-stack-base

lxc profile delete www-"$LXD_VM_NAME"
lxc profile delete btcpay-"$LXD_VM_NAME"
lxc profile delete sovereign-stack

lxc image rm sovereign-stack-base
lxc image rm ubuntu-base

lxc storage delete sovereign-stack

lxc remote switch "local"
lxc remote remove "$CLUSTER_NAME"

source "$HOME/.bashrc"

./cluster.sh create "$CLUSTER_NAME" "$SSH_ENDPOINT.$DOMAIN_NAME"

./deploy.sh
