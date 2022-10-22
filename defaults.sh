#!/bin/bash

set -eu

export DEPLOY_WWW_SERVER=false
export WWW_SERVER_MAC_ADDRESS=
export DEPLOY_BTCPPAY_SERVER=false

export DEPLOY_GHOST=true
export DEPLOY_NOSTR_RELAY=true
export DEPLOY_ONION_SITE=false
export DEPLOY_NEXTCLOUD=false
export DEPLOY_GITEA=false

export WWW_HOSTNAME="www"
export BTCPAY_HOSTNAME="btcpay"
export BTCPAY_HOSTNAME_IN_CERT="tip"
export NEXTCLOUD_HOSTNAME="nextcloud"
export GITEA_HOSTNAME="git"
export NOSTR_HOSTNAME="relay"
export NOSTR_ACCOUNT_PUBKEY=

# used by 'aws' deployments only; planned deprecation
export DDNS_PASSWORD=

# this is where the html is sourced from.
export SITE_HTML_PATH=
export BTCPAY_ADDITIONAL_HOSTNAMES=

# enter your AWS Access Key and Secret Access Key here.
export AWS_ACCESS_KEY=
export AWS_SECRET_ACCESS_KEY=

# if overridden, the app will be deployed to proxy $BTCPAY_HOSTNAME.$DOMAIN_NAME requests to the URL specified.
# this is useful when you want to oursource your BTCPAY fullnode/lightning node.
#export BTCPAY_HANDLER_URL=


export SMTP_SERVER="smtp.mailgun.org"
export SMTP_PORT="587"

# default AWS region and AMI (free-tier AMI ubuntu 20.10)
export AWS_REGION="us-east-1"

# AMI NAME:
# ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20220420
export AWS_AMI_ID="ami-09d56f8956ab235b3"
WWW_INSTANCE_TYPE="t2.small"
BTCPAY_INSTANCE_TYPE="t2.medium"

# goal will be to keep any particular instance to run AT OR BELOW t2.medium. 
# other options are t2.small, micro, nano; micro is the free-tier eligible.
# [1=vCPUs, 1=Mem(GiB)]
# nano [1,0.5], micro [1,1] (free-tier eligible), small [1,2], medium [2,4], large [2,8], xlarge [4,16], 2xlarge [8,32]

export WWW_INSTANCE_TYPE="$WWW_INSTANCE_TYPE"
export BTCPAY_INSTANCE_TYPE="$BTCPAY_INSTANCE_TYPE"

# TODO REMOVE SMTP_PASSWORD ONCE VERIFIED NO LONGER NEEDED
#export SMTP_PASSWORD=
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
export DEV_MEMORY_MB="4096"
export DEV_CPU_COUNT="4"

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




# TODO
# 1 add check for ~/.aws/credentials and stub one out
# 2 ensure install.sh has been run by checking for tor, docker-machine, lxd, wait-for-it, etc.
# 3 pretty much just run the install script if anything is awry
# 4 maybe check to ensure all the CNAME and A+ records are there first so we can quit before machine creation.

BTC_CHAIN=regtest

export BTC_CHAIN="$BTC_CHAIN"

DEFAULT_DB_IMAGE="mariadb:10.9.3-jammy"


# run the docker stack.
export GHOST_IMAGE="ghost:5.18.0"
export GHOST_DB_IMAGE="$DEFAULT_DB_IMAGE"
export NGINX_IMAGE="nginx:1.23.1"

# version of backup is 24.0.3
export NEXTCLOUD_IMAGE="nextcloud:25.0.0"
export NEXTCLOUD_DB_IMAGE="$DEFAULT_DB_IMAGE"

# TODO PIN the gitea version number.
export GITEA_IMAGE="gitea/gitea:latest"
export GITEA_DB_IMAGE="$DEFAULT_DB_IMAGE"

export SOVEREIGN_STACK_MAC_ADDRESS=
export WWW_SERVER_MAC_ADDRESS=
export BTCPAYSERVER_MAC_ADDRESS=

export CLUSTERS_DIR="$HOME/ss-clusters"
export PROJECTS_DIR="$HOME/ss-projects"
export SITES_PATH="$HOME/ss-sites"


# The base VM image.
export BASE_LXC_IMAGE="ubuntu/22.04/cloud"

# Deploy a registry cache on your management machine.
export DEPLOY_MGMT_REGISTRY=true
export OTHER_SITES_LIST=

export REMOTE_HOME="/home/ubuntu"

export BTCPAY_SERVER_APPPATH="$REMOTE_HOME/btcpayserver-docker"
export REMOTE_CERT_BASE_DIR="$REMOTE_HOME/.certs"

# this space is for OS, docker images, etc. DOES NOT INCLUDE USER DATA.
export ROOT_DISK_SIZE_GB=20
