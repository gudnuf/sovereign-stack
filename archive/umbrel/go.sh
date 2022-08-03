#!/bin/bash

set -eu

ssh "$FQDN" "
  set -x

  cd /home/ubuntu

  # first, lets make sure we have the latest code. We use git over HTTPS and store it in ~/umbrel
  # ~/umbrel is the only folder we need to backup
  if [ ! -d ./umbrel ]; then
      git clone https://github.com/getumbrel/umbrel.git ./umbrel
  else
    
      if [ -f ./umbrel/scripts/stop ]; then
          sudo ./umbrel/scripts/stop 
      fi
  fi
"

# # DO SOME BACKUP OPERATION

# ssh "$FQDN" "
#   set -x

#   mkdir -p /home/ubuntu/backup

#   sudo PASSPHRASE=${DUPLICITY_BACKUP_PASSPHRASE} duplicity --exclude ${REMOTE_HOME}/umbrel/bitcoin/blocks ${REMOTE_HOME}/umbrel file://${REMOTE_BACKUP_PATH}
#   sudo chown -R ubuntu:ubuntu ${REMOTE_BACKUP_PATH}
# "

# Start services back up.
ssh "$FQDN" "
  set -e
  cd /home/ubuntu/umbrel

  git config pull.rebase true
  git fetch --all --tags
  git checkout master
  git pull
  git checkout tags/v0.4.18

  # To use Umbrel on mainnet, run:
  sudo NETWORK=$BTC_CHAIN /home/ubuntu/umbrel/scripts/start
"

# we wait for lightning to comone line too.
wait-for-it -t -60 "$FQDN:80"

xdg-open "http://$FQDN" > /dev/null 2>&1
