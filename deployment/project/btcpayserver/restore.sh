#!/bin/bash

set -e
cd "$(dirname "$0")"

if [ "$RESTORE_BTCPAY"  = false ]; then 
    exit 0
fi

if [ -f "$BACKUP_BTCPAY_ARCHIVE_PATH" ]; then
    # push the restoration archive to the remote server
    echo "INFO: Restoring BTCPAY Server: $BACKUP_BTCPAY_ARCHIVE_PATH"

    REMOTE_BACKUP_PATH="$REMOTE_HOME/backups/btcpayserver"
    ssh "$FQDN" mkdir -p "$REMOTE_BACKUP_PATH"
    REMOTE_BTCPAY_ARCHIVE_PATH="$REMOTE_BACKUP_PATH/btcpay.tar.gz"
    scp "$BACKUP_BTCPAY_ARCHIVE_PATH" "$FQDN:$REMOTE_BTCPAY_ARCHIVE_PATH"

    # we clean up any old containers first before restoring.
    ssh "$FQDN" docker system prune -f

    # push the modified restore script to the remote directory, set permissions, and execute.
    scp ./remote_scripts/btcpay-restore.sh "$FQDN:$REMOTE_HOME/btcpay-restore.sh"
    ssh "$FQDN" "sudo mv $REMOTE_HOME/btcpay-restore.sh $BTCPAY_SERVER_APPPATH/btcpay-restore.sh && sudo chmod 0755 $BTCPAY_SERVER_APPPATH/btcpay-restore.sh"
    ssh "$FQDN" "cd $REMOTE_HOME/; sudo BTCPAY_BASE_DIRECTORY=$REMOTE_HOME BTCPAY_DOCKER_COMPOSE=$REMOTE_HOME/btcpayserver-docker/Generated/docker-compose.generated.yml bash -c '$BTCPAY_SERVER_APPPATH/btcpay-restore.sh $REMOTE_BTCPAY_ARCHIVE_PATH'"

    # now, we're going to take things down because aparently we this needs to be re-exececuted.
    ssh "$FQDN" "bash -c $BTCPAY_SERVER_APPPATH/btcpay-down.sh"

else
    echo "ERROR: File does not exist."
    exit 1
fi
