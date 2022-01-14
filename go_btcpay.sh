#!/bin/bash

set -exuo nounset
cd "$(dirname "$0")"

if [ "$RUN_BACKUP"  = true ]; then
    ssh "$FQDN" "cd $REMOTE_HOME/btcpayserver-docker/; sudo bash -c ./btcpay-down.sh" 
fi

# we will re-run the btcpay provisioning scripts if directed to do so.
# if an update does occur, we grab another backup.
if [ "$UPDATE_BTCPAY" = true ]; then

    if [ "$RUN_BACKUP"  = true ]; then
        # grab a backup PRIOR to update
        ./backup_btcpay.sh "before-update-$UNIX_BACKUP_TIMESTAMP"
    fi

    # run the update.
    ssh "$FQDN" "cd $REMOTE_HOME/btcpayserver-docker/; sudo bash -c ./btcpay-update.sh" 

else
    if [ "$RUN_BACKUP"  = true ]; then
        # we just grab a regular backup
        ./backup_btcpay.sh "regular-backup-$UNIX_BACKUP_TIMESTAMP"
    fi
fi

# run a restoration if specified.
if [ "$RUN_RESTORE" = true ]; then
    ssh "$FQDN" "cd $REMOTE_HOME/btcpayserver-docker/; sudo bash -c ./btcpay-down.sh" 
    ./restore_btcpay.sh
fi

# the administrator may have indicated a reconfig; if so, re-run the setup (useful for adding alternative names to TLS)
if [ "$RECONFIGURE_BTCPAY_SERVER"  = true ]; then
    # re-run the setup script.
    ./run_btcpay_setup.sh
fi

if [ "$MIGRATE_BTCPAY_SERVER" = false ]; then
    # The default is to resume services, though admin may want to keep services off (eg., for a migration)
    # we bring the services back up by default.
    ssh "$FQDN" "cd $REMOTE_HOME/btcpayserver-docker/; sudo bash -c ./btcpay-up.sh"

    # we wait for lightning to comone line too.
    wait-for-it -t -60 "$FQDN:80"
    wait-for-it -t -60 "$FQDN:443"

    xdg-open "http://$FQDN"
else
    echo "WARNING: The '--migrate' flag was specified. BTCPay Server services HAVE NOT BEEN TURNED ON!"
    echo "NOTE: You can restore your latest backup to a new host that has BTCPay Server installed."
fi
