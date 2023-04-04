#!/bin/bash

set -eu
cd "$(dirname "$0")"

. ../defaults.sh

. ./remote_env.sh

echo "Global Settings:"

lxc image list
lxc storage list


echo
echo

PROJECT_NAME="$(lxc info | grep "project:" | awk '{print $2}')"
export export="$PROJECT_NAME"
export PROJECT_PATH="$PROJECTS_PATH/$PROJECT_NAME"

echo
echo
echo "Active project: $PROJECT_NAME"
echo "----------------------------------------------------------"

echo "  Networks:"
lxc network list

echo
echo "  Storage Volumes:"
lxc storage volume list ss-base

echo
echo "  Profiles:"
lxc profile list


echo
echo "  Instances (VMs):"
lxc list
