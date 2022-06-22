#!/bin/bash

set -ex

VALUE=${SITE_PATH:-}
if [ -z "$VALUE" ]; then
    echo "ERROR: Your SITE_PATH is undefined. Did you specify the domain correctly?"
    exit 1
fi

# check to see if the enf file exists. exist if not.
if [ ! -d "$SITE_PATH" ]; then
    echo "ERROR: '$SITE_PATH' does not exist."
    exit 1
fi

DOCKER_YAML_PATH="$SITE_PATH/appstack.yml"
export DOCKER_YAML_PATH="$DOCKER_YAML_PATH"
export REMOTE_HOME="/home/ubuntu"

mkdir -p "$SSHFS_PATH"

# VALIDATE THE INPUT from the ENVFILE
if [ -z "$DOMAIN_NAME" ]; then
    echo "ERROR: DOMAIN_NAME not specified. Use the --domain-name= option."
    exit 1
fi

# TODO, ensure VPS_HOSTING_TARGET is in range.
export NEXTCLOUD_FQDN="$NEXTCLOUD_HOSTNAME.$DOMAIN_NAME"
export GITEA_FQDN="$GITEA_HOSTNAME.$DOMAIN_NAME"
export NOSTR_FQDN="$NOSTR_HOSTNAME.$DOMAIN_NAME"

export ADMIN_ACCOUNT_USERNAME="info"
export CERTIFICATE_EMAIL_ADDRESS="$ADMIN_ACCOUNT_USERNAME@$DOMAIN_NAME"
export REMOTE_CERT_BASE_DIR="$REMOTE_HOME/.certs"


export VM_NAME="sovereign-stack-base"
export REMOTE_NEXTCLOUD_PATH="$REMOTE_HOME/nextcloud"
export REMOTE_GITEA_PATH="$REMOTE_HOME/gitea"

# this space is for OS, docker images, etc. DOES NOT INCLUDE USER DATA.
export ROOT_DISK_SIZE_GB=20


export BTC_CHAIN="$BTC_CHAIN"
export ROOT_DISK_SIZE_GB=$ROOT_DISK_SIZE_GB
export WWW_INSTANCE_TYPE="$WWW_INSTANCE_TYPE"

export BTCPAY_ADDITIONAL_HOSTNAMES="$BTCPAY_ADDITIONAL_HOSTNAMES"

