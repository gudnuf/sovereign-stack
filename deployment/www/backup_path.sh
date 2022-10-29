#!/bin/bash

set -eu
cd "$(dirname "$0")"

# TODO: We are using extra space on the remote VPS at the moment for the duplicity backup files.
# we could eliminate that and simply save duplicity backups to the management machine running the script
# this could be done by using a local path and mounting it on the remote VPS.
# maybe something like https://superuser.com/questions/616182/how-to-mount-local-directory-to-remote-like-sshfs

# step 1: run duplicity on the remote system to backup all files to the remote system.
# --allow-source-mismatch

# if the source files to backup don't exist on the remote host, we return.
if ! ssh "$PRIMARY_WWW_FQDN" "[ -d $REMOTE_SOURCE_BACKUP_PATH ]"; then
    echo "INFO: The path to backup does not exist. There's nothing to backup! That's ok, execution will continue."
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

