#!/bin/bash

echo "LXD REMOTE: $(lxc remote get-default)"

lxc project list

lxc storage list
lxc storage volume list ss-base
lxc image list
lxc project list
lxc network list
lxc profile list
lxc list