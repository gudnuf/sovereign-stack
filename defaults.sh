#!/bin/bash

set -e

export DEPLOY_GHOST=true
export DEPLOY_CLAMS=false
export DEPLOY_NOSTR=false
export DEPLOY_NEXTCLOUD=false
export DEPLOY_GITEA=false

export WWW_HOSTNAME="www"
export BTCPAY_HOSTNAME="btcpayserver"
export BTCPAY_HOSTNAME_IN_CERT="btcpay"
export NEXTCLOUD_HOSTNAME="nextcloud"
export GITEA_HOSTNAME="git"
export NOSTR_HOSTNAME="relay"
export CLAMS_HOSTNAME="clams"

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
export PASS_HOME="$HOME/.password-store"


export BTCPAY_SERVER_CPU_COUNT="4"
export BTCPAY_SERVER_MEMORY_MB="4096"
export WWW_SERVER_CPU_COUNT="4"
export WWW_SERVER_MEMORY_MB="4096"

export DOCKER_IMAGE_CACHE_FQDN="registry-1.docker.io"

export NEXTCLOUD_SPACE_GB=10

DEFAULT_DB_IMAGE="mariadb:10.11.2-jammy"


# run the docker stack.
export GHOST_IMAGE="ghost:5.38.0"

# TODO switch to mysql. May require intricate export work for existing sites. 
# THIS MUST BE COMPLETED BEFORE v1 RELEASE
#https://forum.ghost.org/t/how-to-migrate-from-mariadb-10-to-mysql-8/29575
export GHOST_DB_IMAGE="mysql:8.0.32"


export NGINX_IMAGE="nginx:1.23.3"

# version of backup is 24.0.3
export NEXTCLOUD_IMAGE="nextcloud:25.0.4"
export NEXTCLOUD_DB_IMAGE="$DEFAULT_DB_IMAGE"

# TODO PIN the gitea version number.
export GITEA_IMAGE="gitea/gitea:latest"
export GITEA_DB_IMAGE="$DEFAULT_DB_IMAGE"

export NOSTR_RELAY_IMAGE="scsibug/nostr-rs-relay"

export WWW_SERVER_MAC_A DDRESS=
export BTCPAYSERVER_MAC_ADDRESS=

export SS_ROOT_PATH="$HOME/ss"

export REMOTES_PATH="$SS_ROOT_PATH/remotes"
export PROJECTS_PATH="$SS_ROOT_PATH/projects"
export SITES_PATH="$SS_ROOT_PATH/sites"

# mount into ss-mgmt/home/ubuntu/snap/lxd/common/config
export LXD_CONFIG_PATH="$SS_ROOT_PATH/lxd"

# The base VM image.
export LXD_UBUNTU_BASE_VERSION="jammy"
export BASE_IMAGE_VM_NAME="ss-base-${LXD_UBUNTU_BASE_VERSION//./-}"
export BASE_LXC_IMAGE="ubuntu/$LXD_UBUNTU_BASE_VERSION/cloud"
WEEK_NUMBER=$(date +%U)
export UBUNTU_BASE_IMAGE_NAME="ss-ubuntu-${LXD_UBUNTU_BASE_VERSION//./-}"

export DOCKER_BASE_IMAGE_NAME="ss-docker-${LXD_UBUNTU_BASE_VERSION//./-}-$WEEK_NUMBER"

export OTHER_SITES_LIST=
export BTCPAY_ALT_NAMES=
export BITCOIN_CHAIN=regtest
export REMOTE_HOME="/home/ubuntu"
export REMOTE_DATA_PATH="$REMOTE_HOME/ss-data"
export REMOTE_DATA_PATH_LETSENCRYPT="$REMOTE_DATA_PATH/letsencrypt"
export REMOTE_BACKUP_PATH="$REMOTE_HOME/backups"
export BTCPAY_SERVER_APPPATH="$REMOTE_DATA_PATH/btcpayserver-docker"

# this space is for OS, docker images, etc
# values here are fine for regtest generally. Later scripts adjust
# these values based on testnet/mainnet
export WWW_SSDATA_DISK_SIZE_GB=20
export WWW_BACKUP_DISK_SIZE_GB=50
export WWW_DOCKER_DISK_SIZE_GB=30

export BTCPAYSERVER_SSDATA_DISK_SIZE_GB=20
export BTCPAYSERVER_BACKUP_DISK_SIZE_GB=5
export BTCPAYSERVER_DOCKER_DISK_SIZE_GB=30

export REGISTRY_URL="https://index.docker.io/v1"
export PRIMARY_DOMAIN=

# this is the git commit of the project/ sub git repo.
# used in the migration script to switch into past for backup
# then back to present (TARGET_PROJECT_GIT_COMMIT) for restore.
export TARGET_PROJECT_GIT_COMMIT=f05daa9bfb11242eab920fdc4dd490d9bfdd6fbb

# 
export TESTNET_BLOCK_HASH=00000000d8277ba1ca66b40b3e3476629e6f0f97c5b8cfaeabfe402e55db223a
export MAINNET_BLOCK_HASH=000000000000000000047941e3a6102e8896a4ae66b962599568eb25abd6b405



export SS_CACHE_PATH="$SS_ROOT_PATH/cache"
export SS_JAMMY_PATH="$SS_CACHE_PATH/$UBUNTU_BASE_IMAGE_NAME"