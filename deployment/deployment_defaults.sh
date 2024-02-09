#!/bin/bash

set -eu

# file paths
export SSH_HOME="$HOME/.ssh"
export PASS_HOME="$HOME/.password-store" #TODO
export SS_ROOT_PATH="$HOME/ss"
export REMOTES_PATH="$SS_ROOT_PATH/remotes"
export PROJECTS_PATH="$SS_ROOT_PATH/projects"
export SITES_PATH="$SS_ROOT_PATH/sites"
export INCUS_CONFIG_PATH="$SS_ROOT_PATH/incus"
export SS_CACHE_PATH="$SS_ROOT_PATH/cache"

export REMOTE_HOME="/home/ubuntu"
export REMOTE_DATA_PATH="$REMOTE_HOME/ss-data"
export REMOTE_DATA_PATH_LETSENCRYPT="$REMOTE_DATA_PATH/letsencrypt"
export REMOTE_BACKUP_PATH="$REMOTE_HOME/backups"
export BTCPAY_SERVER_APPPATH="$REMOTE_DATA_PATH/btcpayserver-docker"

export BITCOIN_CHAIN=regtest

# this space is for OS, docker images, etc
# values here are fine for regtest generally. Later scripts adjust
# these values based on testnet/mainnet
export WWW_SSDATA_DISK_SIZE_GB=20
export WWW_BACKUP_DISK_SIZE_GB=50
export WWW_DOCKER_DISK_SIZE_GB=30

export BTCPAYSERVER_SSDATA_DISK_SIZE_GB=20
export BTCPAYSERVER_BACKUP_DISK_SIZE_GB=20
export BTCPAYSERVER_DOCKER_DISK_SIZE_GB=30

export WWW_HOSTNAME="www"
export BTCPAY_SERVER_HOSTNAME="btcpayserver"
export LNPLAY_SERVER_HOSTNAME="lnplayserver"
export BTCPAY_HOSTNAME_IN_CERT="btcpay"
export NEXTCLOUD_HOSTNAME="nextcloud"
export GITEA_HOSTNAME="git"
export NOSTR_HOSTNAME="relay"

export REGISTRY_URL="https://index.docker.io/v1"

export BTCPAY_SERVER_CPU_COUNT="4"
export BTCPAY_SERVER_MEMORY_MB="4096"
export WWW_SERVER_CPU_COUNT="4"
export WWW_SERVER_MEMORY_MB="4096"
export LNPLAY_SERVER_CPU_COUNT="4"
export LNPLAY_SERVER_MEMORY_MB="4096"
export DOCKER_IMAGE_CACHE_FQDN="registry-1.docker.io"
