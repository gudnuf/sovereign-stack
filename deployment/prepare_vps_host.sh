#!/bin/bash

set -exu

# scan the remote machine and install it's identity in our SSH known_hosts file.
ssh-keyscan -H -t ecdsa "$FQDN" >> "$SSH_HOME/known_hosts"

# create a directory to store backup archives. This is on all new vms.
ssh "$FQDN" mkdir -p "$REMOTE_HOME/backups"

if [ "$APP_TO_DEPLOY" = btcpay ]; then
    echo "INFO: new machine detected. Provisioning BTCPay server scripts."

    ./run_btcpay_setup.sh
    exit
fi
