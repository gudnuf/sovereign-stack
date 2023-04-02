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

export PROJECT_NAME="$(lxc info | grep "project:" | awk '{print $2}')"
export PROJECT_PATH="$PROJECTS_PATH/$PROJECT_NAME"



echo
echo
echo "Project: $PROJECT_NAME"
echo "----------------------------------------------------------"

echo "  Networks:"
lxc network list
echo
echo "  Profiles:"
lxc profile list
echo
echo "  Instances (VMs):"
lxc list
echo "----------------------------------------------------------"
