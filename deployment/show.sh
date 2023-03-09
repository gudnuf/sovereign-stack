#!/bin/bash

echo "LXD REMOTE: $(lxc remote get-default)"

lxc project list

lxc storage list
lxc image list
lxc project list
lxc network list
lxc profile list
lxc list