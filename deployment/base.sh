#!/bin/bash

# The base VM image.
export LXD_UBUNTU_BASE_VERSION="jammy"
export BASE_IMAGE_VM_NAME="ss-base-${LXD_UBUNTU_BASE_VERSION//./-}"
export BASE_LXC_IMAGE="ubuntu/$LXD_UBUNTU_BASE_VERSION/cloud"
WEEK_NUMBER=$(date +%U)
export UBUNTU_BASE_IMAGE_NAME="ss-ubuntu-${LXD_UBUNTU_BASE_VERSION//./-}"
export DOCKER_BASE_IMAGE_NAME="ss-docker-${LXD_UBUNTU_BASE_VERSION//./-}-$WEEK_NUMBER"
