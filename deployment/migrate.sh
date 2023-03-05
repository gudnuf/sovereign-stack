#!/bin/bash

set -exu
cd "$(dirname "$0")"

USER_SAYS_YES=false

for i in "$@"; do
    case $i in
        -y)
            USER_SAYS_YES=true
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        ;;
    esac
done

. ../defaults.sh

. ./cluster_env.sh

. ./project_env.sh

# Check to see if any of the VMs actually don't exist. 
# (we only migrate instantiated vms)
for VM in www btcpayserver; do
    LXD_NAME="$VM-${DOMAIN_NAME//./-}"

    # if the VM doesn't exist, the we emit an error message and hard quit.
    if ! lxc list --format csv | grep -q "$LXD_NAME"; then
        echo "ERROR: there is no VM named '$LXD_NAME'. You probably need to run ss-deploy again."
        exit 1
    fi
done

BTCPAY_RESTORE_ARCHIVE_PATH="$SITES_PATH/$PRIMARY_DOMAIN/backups/btcpayserver/$(date +%s).tar.gz"
echo "INFO: The BTCPAY_RESTORE_ARCHIVE_PATH for this migration will be: $BTCPAY_RESTORE_ARCHIVE_PATH" 

# first we run ss-deploy --stop
# this grabs a backup of all data (backups are on by default) and saves them to the management machine
# the --stop flag ensures that services do NOT come back online.
# by default, we grab a backup. 

# run deploy which backups up everything, but doesnt restart any services.
bash -c "./deploy.sh --stop --no-cert-renew --backup-archive-path=$BTCPAY_RESTORE_ARCHIVE_PATH"

# call the destroy script. If user proceed, then user data is DESTROYED!
USER_SAYS_YES="$USER_SAYS_YES" ./destroy.sh

# Then we can run a restore operation and specify the backup archive at the CLI.
bash -c "./deploy.sh -y --restore-www --restore-btcpay --backup-archive-path=$BTCPAY_RESTORE_ARCHIVE_PATH"
