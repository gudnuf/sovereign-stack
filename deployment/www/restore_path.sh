#!/bin/bash

set -eux
cd "$(dirname "$0")"

FILE_COUNT="$(find "$LOCAL_BACKUP_PATH" -type f | wc -l)"
if [ "$FILE_COUNT" = 0 ]; then
    echo "ERROR: there are no files in the local backup path '$LOCAL_BACKUP_PATH'."
    echo "We're going to continue with execution."
    exit 0
fi

RESPONSE=
read -r -p "Are you sure you want to restore the local path '$LOCAL_BACKUP_PATH' to the remote server at '$PRIMARY_WWW_FQDN' (y/n)": RESPONSE
if [ "$RESPONSE" != y ]; then
    echo "STOPPING."
    exit 0
fi

# delete the target backup path so we can push restoration files from the management machine.
ssh "$PRIMARY_WWW_FQDN" sudo rm -rf "$REMOTE_SOURCE_BACKUP_PATH"

# scp our local backup directory to the remote machine
ssh "$PRIMARY_WWW_FQDN" sudo mkdir -p "$REMOTE_BACKUP_PATH"
ssh "$PRIMARY_WWW_FQDN" sudo chown ubuntu:ubuntu "$REMOTE_BACKUP_PATH"

scp -r "$LOCAL_BACKUP_PATH" "$PRIMARY_WWW_FQDN:$REMOTE_BACKUP_PATH"

# now we run duplicity to restore the archive.
ssh "$PRIMARY_WWW_FQDN" sudo PASSPHRASE="$DUPLICITY_BACKUP_PASSPHRASE" duplicity --force restore "file://$REMOTE_BACKUP_PATH/$BACKUP_TIMESTAMP" "$REMOTE_SOURCE_BACKUP_PATH/"

