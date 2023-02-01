#!/bin/bash

set -eu
cd "$(dirname "$0")"

# this script backups up a source path to a destination folder on the remote VM
# then pulls that data down to the maanagement environment

# if the source files to backup don't exist on the remote host, we return.
if ! ssh "$PRIMARY_WWW_FQDN" "[ -d $REMOTE_SOURCE_BACKUP_PATH ]"; then
    exit 0
fi

ssh "$PRIMARY_WWW_FQDN" sudo PASSPHRASE="$DUPLICITY_BACKUP_PASSPHRASE" duplicity "$REMOTE_SOURCE_BACKUP_PATH" "file://$REMOTE_BACKUP_PATH"
ssh "$PRIMARY_WWW_FQDN" sudo chown -R ubuntu:ubuntu "$REMOTE_BACKUP_PATH"

SSHFS_PATH="/tmp/sshfs_temp"
mkdir -p "$SSHFS_PATH"

# now let's pull down the latest files from the backup directory.
# create a temp directory to serve as the mountpoint for the remote machine backups directory
sshfs "$PRIMARY_WWW_FQDN:$REMOTE_BACKUP_PATH" "$SSHFS_PATH"

# rsync the files from the remote server to our local backup path.
rsync -av "$SSHFS_PATH/" "$LOCAL_BACKUP_PATH/"

# step 4: unmount the SSHFS filesystem and cleanup.
umount "$SSHFS_PATH"
rm -rf "$SSHFS_PATH"
