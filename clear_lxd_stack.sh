#!/bin/bash

LXD_VM_NAME="www-sovereign-stack-org"

lxc delete -f "$LXD_VM_NAME"

lxc profile delete "$LXD_VM_NAME"

lxc image delete "sovereign-stack-base" "ubuntu-21-04"

#lxc storage delete default
