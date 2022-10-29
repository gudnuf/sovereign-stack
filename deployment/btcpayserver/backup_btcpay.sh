#!/bin/bash

set -e
cd "$(dirname "$0")"

# take the services down, create a backup archive, then pull it down.
# the script executed here from the BTCPAY repo will automatically take services down
# and bring them back up.

echo "INFO: Starting BTCPAY Backup script for host '$BTCPAY_FQDN'."

ssh "$BTCPAY_FQDN" "mkdir -p $REMOTE_HOME/backups; cd $REMOTE_HOME/; sudo BTCPAY_BASE_DIRECTORY=$REMOTE_HOME bash -c $BTCPAY_SERVER_APPPATH/btcpay-down.sh"

# TODO enable encrypted archives
# TODO switch to btcpay-backup.sh when on LXD fully.
scp ./remote_scripts/btcpay-backup.sh "$BTCPAY_FQDN:$REMOTE_HOME/btcpay-backup.sh"
ssh "$BTCPAY_FQDN" "sudo cp $REMOTE_HOME/btcpay-backup.sh $BTCPAY_SERVER_APPPATH/btcpay-backup.sh && sudo chmod 0755 $BTCPAY_SERVER_APPPATH/btcpay-backup.sh"
ssh "$BTCPAY_FQDN" "cd $REMOTE_HOME/; sudo BTCPAY_BASE_DIRECTORY=$REMOTE_HOME BTCPAY_DOCKER_COMPOSE=$REMOTE_HOME/btcpayserver-docker/Generated/docker-compose.generated.yml bash -c $BTCPAY_SERVER_APPPATH/btcpay-backup.sh"

# next we pull the resulting backup archive down to our management machine.
ssh "$BTCPAY_FQDN" "sudo cp /var/lib/docker/volumes/backup_datadir/_data/backup.tar.gz $REMOTE_HOME/backups/btcpay.tar.gz"
ssh "$BTCPAY_FQDN" "sudo chown ubuntu:ubuntu $REMOTE_HOME/backups/btcpay.tar.gz"


mkdir -p "$BTCPAY_LOCAL_BACKUP_PATH"
scp "$BTCPAY_FQDN:$REMOTE_HOME/backups/btcpay.tar.gz" "$BTCPAY_LOCAL_BACKUP_ARCHIVE_PATH"

echo "INFO: Created backup archive '$BTCPAY_LOCAL_BACKUP_ARCHIVE_PATH' for host '$BTCPAY_FQDN'."
