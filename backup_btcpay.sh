#!/bin/bash

set -ex

# take the services down, create a backup archive, then pull it down.
ssh "$FQDN" "cd $REMOTE_HOME/btcpayserver-docker/; sudo bash -c ./backup.sh"
ssh "$FQDN" "sudo cp /var/lib/docker/volumes/backup_datadir/_data/backup.tar.gz $REMOTE_HOME/backups/btcpay.tar.gz"
ssh "$FQDN" "sudo chown ubuntu:ubuntu $REMOTE_HOME/backups/btcpay.tar.gz"
scp "$FQDN:$REMOTE_HOME/backups/btcpay.tar.gz" "$LOCAL_BACKUP_PATH/btcpay-$1.tar.gz"
