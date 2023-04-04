#!/bin/bash

set -eu

PROJECT_NAME="$(lxc info | grep "project:" | awk '{print $2}')"
export PROJECT_NAME="$PROJECT_NAME"

if [ "$PROJECT_NAME" = default ]; then
    echo "ERROR: You are on the default project. Use 'lxc project list' and 'lxc project switch <project>'."
    exit 1
fi

BITCOIN_CHAIN=$(echo "$PROJECT_NAME" | cut -d'-' -f2)

export PROJECT_PATH="$PROJECTS_PATH/$PROJECT_NAME"
export BITCOIN_CHAIN="$BITCOIN_CHAIN"

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

SHASUM_OF_PRIMARY_DOMAIN="$(echo -n "$PRIMARY_DOMAIN" | sha256sum | awk '{print $1;}' )"
export PRIMARY_DOMAIN_IDENTIFIER="${SHASUM_OF_PRIMARY_DOMAIN: -6}"

export WWW_SSDATA_DISK_SIZE_GB="$WWW_SSDATA_DISK_SIZE_GB"
export WWW_BACKUP_DISK_SIZE_GB="$WWW_BACKUP_DISK_SIZE_GB"
export WWW_DOCKER_DISK_SIZE_GB="$WWW_DOCKER_DISK_SIZE_GB"

export BTCPAYSERVER_SSDATA_DISK_SIZE_GB="$BTCPAYSERVER_SSDATA_DISK_SIZE_GB"
export BTCPAYSERVER_BACKUP_DISK_SIZE_GB="$BTCPAYSERVER_BACKUP_DISK_SIZE_GB"
export BTCPAYSERVER_DOCKER_DISK_SIZE_GB="$BTCPAYSERVER_DOCKER_DISK_SIZE_GB"
