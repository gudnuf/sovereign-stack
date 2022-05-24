#!/bin/bash

u

# this scripts ASSUMES services have already been taken down.

# first let's ask the user for the absolute path to the backup file that we want to restore.
FILE_PATH=
read -r -p "Please enter the absolute path of the backup file you want to restore:  ": FILE_PATH
if [ -f "$FILE_PATH" ]; then
    # then we grab a backup of the existing stuff BEFORE the restoration attempt
    ./backup_btcpay.sh "before-restore-$UNIX_BACKUP_TIMESTAMP"

    echo "INFO: Restoring BTCPAY Server: $FILE_PATH"
    ssh "$FQDN" mkdir -p "$REMOTE_BACKUP_PATH"
    scp "$FILE_PATH" "$FQDN:$REMOTE_BACKUP_PATH/btcpay.tar.gz"
    ssh "$FQDN" "cd /; sudo tar -xzvf $REMOTE_BACKUP_PATH/btcpay.tar.gz"
else
    echo "ERROR: File does not exist."
    exit 1
fi
