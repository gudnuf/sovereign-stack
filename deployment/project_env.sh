#!/bin/bash

set -eu
cd "$(dirname "$0")"

PROJECT_DEFINITION_PATH="$PROJECT_PATH/project.conf"

if [ ! -f "$PROJECT_DEFINITION_PATH" ]; then
    echo "ERROR: 'project.conf' not found $PROJECT_DEFINITION_PATH not found."
    exit 1
fi

source "$PROJECT_DEFINITION_PATH"

export PRIMARY_SITE_DEFINITION_PATH="$SITES_PATH/$PRIMARY_DOMAIN/site.conf"

if [ ! -f "$PRIMARY_SITE_DEFINITION_PATH" ]; then
    echo "ERROR: the site definition does not exist."
    exit 1
fi

if [ -z "$PRIMARY_DOMAIN" ]; then
    echo "ERROR: The PRIMARY_DOMAIN is not specified. Check your remote definition at '$PRIMARY_SITE_DEFINITION_PATH'."
    exit 1
fi

source "$PRIMARY_SITE_DEFINITION_PATH"

if ! lxc info | grep "project:" | grep -q "$PROJECT_NAME"; then
    if lxc project list | grep -q "$PROJECT_NAME"; then
        lxc project switch "$PROJECT_NAME"
    fi
fi

SHASUM_OF_PRIMARY_DOMAIN="$(echo -n "$PRIMARY_DOMAIN" | sha256sum | awk '{print $1;}' )"
export PRIMARY_DOMAIN_IDENTIFIER="${SHASUM_OF_PRIMARY_DOMAIN: -6}"

export WWW_SSDATA_DISK_SIZE_GB="$WWW_SSDATA_DISK_SIZE_GB"
export WWW_BACKUP_DISK_SIZE_GB="$WWW_BACKUP_DISK_SIZE_GB"
export WWW_DOCKER_DISK_SIZE_GB="$WWW_DOCKER_DISK_SIZE_GB"

export BTCPAYSERVER_SSDATA_DISK_SIZE_GB="$BTCPAYSERVER_SSDATA_DISK_SIZE_GB"
export BTCPAYSERVER_BACKUP_DISK_SIZE_GB="$BTCPAYSERVER_BACKUP_DISK_SIZE_GB"
export BTCPAYSERVER_DOCKER_DISK_SIZE_GB="$BTCPAYSERVER_DOCKER_DISK_SIZE_GB"
