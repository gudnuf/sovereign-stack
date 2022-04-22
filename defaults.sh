#!/bin/bash

set -eu

export DEPLOY_WWW_SERVER=false
export DEPLOY_BTCPPAY_SERVER=false
export DEPLOY_UMBREL_VPS=false

# if true, then we deploy a VPS with Jitsi/Matrix
export DEPLOY_GHOST=true
export DEPLOY_MATRIX=false
export DEPLOY_NOSTR=false
export DEPLOY_ONION_SITE=false
export DEPLOY_NEXTCLOUD=false
export DEPLOY_GITEA=false

export WWW_HOSTNAME="www"
export BTCPAY_HOSTNAME="btcpay"
export UMBREL_HOSTNAME="umbrel"
export NEXTCLOUD_HOSTNAME="nextcloud"
export MATRIX_HOSTNAME="chat"
export GITEA_HOSTNAME="git"
export NOSTR_HOSTNAME="messages"
export NOSTR_ACCOUNT_PUBKEY=

export DDNS_PASSWORD=

# this is where the html is sourced from.
export SITE_HTML_PATH=

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
# ubuntu-minimal/images/hvm-ssd/ubuntu-impish-21.10-amd64-minimal-20220308-f7c42f71-5c9c-40c0-b808-ada8557fe9a2
export AWS_AMI_ID="ami-0ab880898e027d4c1"
WWW_INSTANCE_TYPE="t2.micro"
BTCPAY_INSTANCE_TYPE="t2.medium"

# goal will be to keep any particular instance to run AT OR BELOW t2.medium. 
# other options are t2.small, micro, nano; micro is the free-tier eligible.
# [1=vCPUs, 1=Mem(GiB)]
# nano [1,0.5], micro [1,1] (free-tier eligible), small [1,2], medium [2,4], large [2,8], xlarge [4,16], 2xlarge [8,32]

export WWW_INSTANCE_TYPE="$WWW_INSTANCE_TYPE"
export BTCPAY_INSTANCE_TYPE="$BTCPAY_INSTANCE_TYPE"

export SMTP_PASSWORD=
export GHOST_MYSQL_PASSWORD=
export GHOST_MYSQL_ROOT_PASSWORD=
export NEXTCLOUD_MYSQL_PASSWORD=
export GITEA_MYSQL_PASSWORD=
export NEXTCLOUD_MYSQL_ROOT_PASSWORD=
export GITEA_MYSQL_ROOT_PASSWORD=
export DUPLICITY_BACKUP_PASSPHRASE=
#opt-add-fireflyiii;opt-add-zammad
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-save-storage;opt-add-btctransmuter;opt-add-configurator;"
export SSH_HOME="$HOME/.ssh"
export VLAN_INTERFACE=
export CACHE_DIR="$HOME/cache"
export VM_NAME=
export DEV_MEMORY_MB="4096"
export DEV_CPU_COUNT="4"
export SSHFS_PATH="/tmp/sshfs_temp"

export NEXTCLOUD_SPACE_GB=10

# TODO add LXD check to ensure it's installed.
DEV_LXD_REMOTE="$(lxc remote get-default)"
export DEV_LXD_REMOTE="$DEV_LXD_REMOTE"

export SITE_TITLE=

# we use this later when we create a VM, we annotate what git commit (from a tag) we used.
LATEST_GIT_TAG="$(git describe --abbrev=0)"
export LATEST_GIT_TAG="$LATEST_GIT_TAG"

LATEST_GIT_COMMIT="$(cat ./.git/refs/heads/master)"
export LATEST_GIT_COMMIT="$LATEST_GIT_COMMIT"


# let's ensure all the tools are installed
if [ ! -f "$(which rsync)" ]; then
    echo "ERROR: rsync is not installed. You may want to install your dependencies."
    exit 1
fi

# shellcheck disable=1091
export SITE_PATH="$HOME/.sites"
export LXD_DISK_TO_USE=


ENABLE_NGINX_CACHING=false



# TODO
# 1 add check for ~/.aws/credentials and stub one out
# 2 ensure install.sh has been run by checking for tor, docker-machine, lxd, wait-for-it, etc.
# 3 pretty much just run the install script if anything is awry
# 4 maybe check to ensure all the CNAME and A+ records are there first so we can quit before machine creation.

export SITE_PATH="$SITE_PATH/$DOMAIN_NAME"
if [ ! -d "$SITE_PATH" ]; then
    echo "ERROR: '$SITE_PATH' does not exist."
    exit 1
fi

export SITE_PATH="$SITE_PATH"
export BTC_CHAIN="$BTC_CHAIN"

# if we're running aws/public, we enable nginx caching since it's a public site.
if [ "$VPS_HOSTING_TARGET" = aws ]; then
    # TODO the correct behavior is to be =true, but cookies aren't working right now.
    ENABLE_NGINX_CACHING=true
fi

DEFAULT_DB_IMAGE="mariadb:10.6.5"
export ENABLE_NGINX_CACHING="$ENABLE_NGINX_CACHING"

# run the docker stack.
export GHOST_IMAGE="ghost:4.44.0"
export GHOST_DB_IMAGE="$DEFAULT_DB_IMAGE"
export NGINX_IMAGE="nginx:1.21.6"
export NEXTCLOUD_IMAGE="nextcloud:23.0.2"
export NEXTCLOUD_DB_IMAGE="$DEFAULT_DB_IMAGE"
export MATRIX_IMAGE="matrixdotorg/synapse:v1.52.0"
export MATRIX_DB_IMAGE="postgres:13.6"
export GITEA_IMAGE="gitea/gitea:latest"
export GITEA_DB_IMAGE="$DEFAULT_DB_IMAGE"
