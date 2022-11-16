#!/bin/bash

set -eu

export WWW_SERVER_MAC_ADDRESS=
export DEPLOY_WWW_SERVER=false
export DEPLOY_BTCPAY_SERVER=false
export DEPLOY_GHOST=false
export DEPLOY_NOSTR_RELAY=false
export DEPLOY_ONION_SITE=false
export DEPLOY_NEXTCLOUD=false
export DEPLOY_GITEA=false

export WWW_HOSTNAME="www"
export BTCPAY_HOSTNAME="btcpayserver"
export BTCPAY_HOSTNAME_IN_CERT="btcpay"
export NEXTCLOUD_HOSTNAME="nextcloud"
export GITEA_HOSTNAME="git"
export NOSTR_HOSTNAME="relay"

export SITE_LANGUAGE_CODES="en"
export LANGUAGE_CODE="en"
export NOSTR_ACCOUNT_PUBKEY=

# this is where the html is sourced from.
export SITE_HTML_PATH=
export BTCPAY_ADDITIONAL_HOSTNAMES=

export GHOST_MYSQL_PASSWORD=
export GHOST_MYSQL_ROOT_PASSWORD=
export NEXTCLOUD_MYSQL_PASSWORD=
export GITEA_MYSQL_PASSWORD=
export NEXTCLOUD_MYSQL_ROOT_PASSWORD=
export GITEA_MYSQL_ROOT_PASSWORD=
export DUPLICITY_BACKUP_PASSPHRASE=
#opt-add-fireflyiii;opt-add-zammad


export SSH_HOME="$HOME/.ssh"
export VLAN_INTERFACE=
export VM_NAME="sovereign-stack-base"
export DEV_MEMORY_MB="8096"
export DEV_CPU_COUNT="6"

export DOCKER_IMAGE_CACHE_FQDN="registry-1.docker.io"

export NEXTCLOUD_SPACE_GB=10

# first of all, if there are uncommited changes, we quit. You better stash or commit!
# Remote VPS instances are tagged with your current git HEAD so we know which code revision
# used when provisioning the VPS.
#LATEST_GIT_COMMIT="$(cat ./.git/refs/heads/master)"
#export LATEST_GIT_COMMIT="$LATEST_GIT_COMMIT"

# check if there are any uncommited changes. It's dangerous to instantiate VMs using
# code that hasn't been committed.
# if git update-index --refresh | grep -q "needs update"; then
#     echo "ERROR: You have uncommited changes! Better stash your work with 'git stash'."
#     exit 1
# fi

BTC_CHAIN=regtest

export BTC_CHAIN="$BTC_CHAIN"

DEFAULT_DB_IMAGE="mariadb:10.9.3-jammy"


# run the docker stack.
export GHOST_IMAGE="ghost:5.20.0"

# TODO switch to mysql. May require intricate export work for existing sites. 
# THIS MUST BE COMPLETED BEFORE v1 RELEASE
#https://forum.ghost.org/t/how-to-migrate-from-mariadb-10-to-mysql-8/29575
export GHOST_DB_IMAGE="$DEFAULT_DB_IMAGE"


export NGINX_IMAGE="nginx:1.23.2"

# version of backup is 24.0.3
export NEXTCLOUD_IMAGE="nextcloud:25.0.0"
export NEXTCLOUD_DB_IMAGE="$DEFAULT_DB_IMAGE"

# TODO PIN the gitea version number.
export GITEA_IMAGE="gitea/gitea:latest"
export GITEA_DB_IMAGE="$DEFAULT_DB_IMAGE"

export NOSTR_RELAY_IMAGE="scsibug/nostr-rs-relay"

export SOVEREIGN_STACK_MAC_ADDRESS=
export WWW_SERVER_MAC_ADDRESS=
export BTCPAYSERVER_MAC_ADDRESS=

export CLUSTERS_DIR="$HOME/ss-clusters"
export PROJECTS_DIR="$HOME/ss-projects"
export SITES_PATH="$HOME/ss-sites"


# The base VM image.
export BASE_LXC_IMAGE="ubuntu/22.04/cloud"

# Deploy a registry cache on your management machine.
export DEPLOY_MGMT_REGISTRY=false
export OTHER_SITES_LIST=
export BTCPAY_ALT_NAMES=

export REMOTE_HOME="/home/ubuntu"

export BTCPAY_SERVER_APPPATH="$REMOTE_HOME/btcpayserver-docker"
export REMOTE_CERT_BASE_DIR="$REMOTE_HOME/.certs"

# this space is for OS, docker images, etc. DOES NOT INCLUDE USER DATA.
export ROOT_DISK_SIZE_GB=20
export REGISTRY_URL="https://index.docker.io/v1/"
