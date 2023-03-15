#!/bin/bash

set -e

export DEPLOY_GHOST=true
export DEPLOY_CLAMS=true

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

DEFAULT_DB_IMAGE="mariadb:10.9.3-jammy"


# run the docker stack.
export GHOST_IMAGE="ghost:5.38.0"

# TODO switch to mysql. May require intricate export work for existing sites. 
# THIS MUST BE COMPLETED BEFORE v1 RELEASE
#https://forum.ghost.org/t/how-to-migrate-from-mariadb-10-to-mysql-8/29575
export GHOST_DB_IMAGE="$DEFAULT_DB_IMAGE"


export NGINX_IMAGE="nginx:1.23.3"

# version of backup is 24.0.3
export NEXTCLOUD_IMAGE="nextcloud:25.0.4"
export NEXTCLOUD_DB_IMAGE="$DEFAULT_DB_IMAGE"

# TODO PIN the gitea version number.
export GITEA_IMAGE="gitea/gitea:latest"
export GITEA_DB_IMAGE="$DEFAULT_DB_IMAGE"

export NOSTR_RELAY_IMAGE="scsibug/nostr-rs-relay"

export WWW_SERVER_MAC_ADDRESS=
export BTCPAYSERVER_MAC_ADDRESS=

export REMOTES_DIR="$HOME/ss-remotes"
export PROJECTS_DIR="$HOME/ss-projects"
export SITES_PATH="$HOME/ss-sites"

# The base VM image.
export LXD_UBUNTU_BASE_VERSION="jammy"
export BASE_IMAGE_VM_NAME="ss-base-${LXD_UBUNTU_BASE_VERSION//./-}"
export BASE_LXC_IMAGE="ubuntu/$LXD_UBUNTU_BASE_VERSION/cloud"
export UBUNTU_BASE_IMAGE_NAME="ss-ubuntu-${LXD_UBUNTU_BASE_VERSION//./-}"
export DOCKER_BASE_IMAGE_NAME="ss-docker-${LXD_UBUNTU_BASE_VERSION//./-}"

export OTHER_SITES_LIST=
export BTCPAY_ALT_NAMES=
export BITCOIN_CHAIN=regtest
export REMOTE_HOME="/home/ubuntu"

export BTCPAY_SERVER_APPPATH="$REMOTE_HOME/btcpayserver-docker"
export REMOTE_CERT_BASE_DIR="$REMOTE_HOME/.certs"

# this space is for OS, docker images, etc. DOES NOT INCLUDE USER DATA.
export ROOT_DISK_SIZE_GB=20
export REGISTRY_URL="https://index.docker.io/v1/"
export PRIMARY_DOMAIN=

# this is the git commit of the project/ sub git repo.
# used in the migration script to switch into past for backup
# then back to present (TARGET_PROJECT_GIT_COMMIT) for restore.
export TARGET_PROJECT_GIT_COMMIT=29acc1796dca29f56f80005f869d3bdc1faf6c58
