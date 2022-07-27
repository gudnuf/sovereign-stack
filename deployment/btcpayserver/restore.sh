#!/bin/bash

set -ex
cd "$(dirname "$0")"

#ssh "$FQDN" "sudo bash -c $BTCPAY_SERVER_APPPATH/btcpay-down.sh"

# first let's ask the user for the absolute path to the backup file that we want to restore.
BTCPAY_SERVER_ARCHIVE="$LOCAL_BACKUP_PATH/$UNIX_BACKUP_TIMESTAMP.tar.gz"
if [ ! -f "$BTCPAY_SERVER_ARCHIVE" ]; then
    BTCPAY_SERVER_ARCHIVE="$RESTORE_ARCHIVE"
fi

if [ -f "$BTCPAY_SERVER_ARCHIVE" ]; then
    # push the restoration archive to the remote server
    echo "INFO: Restoring BTCPAY Server: $BTCPAY_SERVER_ARCHIVE"
    ssh "$FQDN" mkdir -p "$REMOTE_BACKUP_PATH"
    REMOTE_BTCPAY_ARCHIVE_PATH="$REMOTE_HOME/backups/btcpay.tar.gz"
    scp "$BTCPAY_SERVER_ARCHIVE" "$FQDN:$REMOTE_BTCPAY_ARCHIVE_PATH"

    # take down services, if any.
    ssh "$FQDN" "cd $REMOTE_HOME/; sudo BTCPAY_BASE_DIRECTORY=$REMOTE_HOME bash -c $BTCPAY_SERVER_APPPATH/btcpay-down.sh"

    # push the modified restore script to the remote directory, set permissions, and execute.
    scp ./btcpay-restore.sh "$FQDN:$REMOTE_HOME/btcpay-restore.sh"
    ssh "$FQDN" "sudo mv $REMOTE_HOME/btcpay-restore.sh $BTCPAY_SERVER_APPPATH/btcpay-restore.sh && sudo chmod 0755 $BTCPAY_SERVER_APPPATH/btcpay-restore.sh"
    ssh "$FQDN" "cd $REMOTE_HOME/; sudo BTCPAY_BASE_DIRECTORY=$REMOTE_HOME BTCPAY_DOCKER_COMPOSE=$REMOTE_HOME/btcpayserver-docker/Generated/docker-compose.generated.yml bash -c '$BTCPAY_SERVER_APPPATH/btcpay-restore.sh $REMOTE_BTCPAY_ARCHIVE_PATH'"

else
    echo "ERROR: File does not exist."
    exit 1
fi
