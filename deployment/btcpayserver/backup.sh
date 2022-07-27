#!/bin/bash

set -exo
cd "$(dirname "$0")"

# take the services down, create a backup archive, then pull it down.
# the script executed here from the BTCPAY repo will automatically take services down
# and bring them back up.

#ssh "$FQDN" "cd $REMOTE_HOME/; sudo BTCPAY_BASE_DIRECTORY=$REMOTE_HOME bash -c $BTCPAY_SERVER_APPPATH/btcpay-down.sh"

# TODO enable encrypted archives
# TODO switch to btcpay-backup.sh when on LXD fully.
scp ./btcpay-backup.sh "$FQDN:$REMOTE_HOME/btcpay-backup.sh"
ssh "$FQDN" "sudo cp $REMOTE_HOME/btcpay-backup.sh $BTCPAY_SERVER_APPPATH/btcpay-backup.sh && sudo chmod 0755 $BTCPAY_SERVER_APPPATH/btcpay-backup.sh"
ssh "$FQDN" "cd $REMOTE_HOME/; sudo BTCPAY_BASE_DIRECTORY=$REMOTE_HOME BTCPAY_DOCKER_COMPOSE=$REMOTE_HOME/btcpayserver-docker/Generated/docker-compose.generated.yml bash -c $BTCPAY_SERVER_APPPATH/btcpay-backup.sh"

# next we pull the resulting backup archive down to our management machine.
ssh "$FQDN" "sudo cp /var/lib/docker/volumes/backup_datadir/_data/backup.tar.gz $REMOTE_HOME/backups/btcpay.tar.gz"
ssh "$FQDN" "sudo chown ubuntu:ubuntu $REMOTE_HOME/backups/btcpay.tar.gz"

scp "$FQDN:$REMOTE_HOME/backups/btcpay.tar.gz" "$LOCAL_BACKUP_PATH/$1.tar.gz"
