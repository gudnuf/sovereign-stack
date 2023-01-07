#!/bin/bash

set -eu

export DOMAIN_NAME=
export DUPLICITY_BACKUP_PASSPHRASE=
export BTCPAY_HOSTNAME_IN_CERT=
export DEPLOY_GHOST=true
export DEPLOY_NEXTCLOUD=false
export NOSTR_ACCOUNT_PUBKEY=
export DEPLOY_GITEA=false
export DEPLOY_ONION_SITE=false
export GHOST_MYSQL_PASSWORD=
export GHOST_MYSQL_ROOT_PASSWORD=
export NEXTCLOUD_MYSQL_PASSWORD=
export NEXTCLOUD_MYSQL_ROOT_PASSWORD=
export GITEA_MYSQL_PASSWORD=
export GITEA_MYSQL_ROOT_PASSWORD=
export LANGUAGE_CODE="en"

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/defaults.sh"
