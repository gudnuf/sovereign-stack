#!/bin/bash

set -exu

# first, this is a restore operation. We need to ask the administrator
# if they want to continue because it results in data loss.
# indeed, our first step is the delete the home directory on the remote server.

# delete the home directory so we know we are restoring all files from the duplicity archive.
ssh "$WWW_FQDN" sudo rm -rf "$REMOTE_HOME/*"

# scp our local backup directory to the remote machine
ssh "$WWW_FQDN" mkdir -p "$REMOTE_BACKUP_PATH"

# TODO instead of scp the files up there, lets' mount the local backup folder to a remote folder then just run a duplicity restore.
scp -r "$LOCAL_BACKUP_PATH/" "$WWW_FQDN:$REMOTE_HOME/backups/$VIRTUAL_MACHINE"

# now we run duplicity to restore the archive.
ssh "$WWW_FQDN" sudo PASSPHRASE="$DUPLICITY_BACKUP_PASSPHRASE" duplicity --force restore "file://$REMOTE_BACKUP_PATH/" "$REMOTE_HOME/"
