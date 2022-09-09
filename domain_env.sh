#!/bin/bash

set -ex

# TODO, ensure VPS_HOSTING_TARGET is in range.
export NEXTCLOUD_FQDN="$NEXTCLOUD_HOSTNAME.$DOMAIN_NAME"
export BTCPAY_FQDN="$BTCPAY_HOSTNAME.$DOMAIN_NAME"
export BTCPAY_USER_FQDN="$BTCPAY_HOSTNAME_IN_CERT.$DOMAIN_NAME"
export WWW_FQDN="$WWW_HOSTNAME.$DOMAIN_NAME"
export GITEA_FQDN="$GITEA_HOSTNAME.$DOMAIN_NAME"
export NOSTR_FQDN="$NOSTR_HOSTNAME.$DOMAIN_NAME"
export ADMIN_ACCOUNT_USERNAME="info"
export CERTIFICATE_EMAIL_ADDRESS="$ADMIN_ACCOUNT_USERNAME@$DOMAIN_NAME"
export REMOTE_NEXTCLOUD_PATH="$REMOTE_HOME/nextcloud"
export REMOTE_GITEA_PATH="$REMOTE_HOME/gitea"
export BTC_CHAIN="$BTC_CHAIN"
export WWW_INSTANCE_TYPE="$WWW_INSTANCE_TYPE"
export BTCPAY_ADDITIONAL_HOSTNAMES="$BTCPAY_ADDITIONAL_HOSTNAMES"
