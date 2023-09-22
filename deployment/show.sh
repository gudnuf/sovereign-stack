#!/bin/bash

set -e
cd "$(dirname "$0")"

. ./deployment_defaults.sh

. ./remote_env.sh

echo "Global Settings:"

incus image list
incus storage list


echo
echo

PROJECT_NAME="$(incus info | grep "project:" | awk '{print $2}')"
export export="$PROJECT_NAME"
export PROJECT_PATH="$PROJECTS_PATH/$PROJECT_NAME"

echo
echo
echo "Active project: $PROJECT_NAME"
echo "----------------------------------------------------------"

echo "  Networks:"
incus network list

echo
echo "  Storage Volumes:"
incus storage volume list ss-base

echo
echo "  Profiles:"
incus profile list


echo
echo "  Instances (VMs):"
incus list
