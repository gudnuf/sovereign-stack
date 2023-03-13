#!/bin/bash

set -eu
cd "$(dirname "$0")"


# check if there are any uncommited changes. It's dangerous to 
# alter production systems when you have commits to make or changes to stash.
if git update-index --refresh | grep -q "needs update"; then
    echo "ERROR: You have uncommited changes! You MUST commit or stash all changes to continue."
    exit 1
fi


. ../defaults.sh

. ./remote_env.sh

for PROJECT_CHAIN in ${DEPLOYMENT_STRING//,/ }; do
    NO_PARENS="${PROJECT_CHAIN:1:${#PROJECT_CHAIN}-2}"
    PROJECT_PREFIX=$(echo "$NO_PARENS" | cut -d'|' -f1)
    BITCOIN_CHAIN=$(echo "$NO_PARENS" | cut -d'|' -f2)
    export PROJECT_PREFIX="$PROJECT_PREFIX"
    export BITCOIN_CHAIN="$BITCOIN_CHAIN"

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

    # first, let's grab the GIT commit from the remote machine.
    export DOMAIN_NAME="$PRIMARY_DOMAIN"
    export SITE_PATH="$SITES_PATH/$PRIMARY_DOMAIN"

    # source the site path so we know what features it has.
    source ../defaults.sh
    source "$SITE_PATH/site_definition"
    source ./project/domain_env.sh

    # now we want to switch the git HEAD of the project subdirectory to the 
    # version of code that was last used
    GIT_COMMIT_ON_REMOTE_HOST="$(ssh ubuntu@$BTCPAY_FQDN cat /home/ubuntu/.ss-githead)"
    cd project/
    git checkout "$GIT_COMMIT_ON_REMOTE_HOST"
    cd -
    sleep 5

    # run deploy which backups up everything, but doesnt restart any services.
    bash -c "./project/deploy.sh --stop --no-cert-renew --backup-archive-path=$BTCPAY_RESTORE_ARCHIVE_PATH"

    # call the destroy script. If user proceed, then user data is DESTROYED!
    ./destroy.sh

    cd project/
    git checkout "$TARGET_PROJECT_GIT_COMMIT"
    cd -

    sleep 5
    # Then we can run a restore operation and specify the backup archive at the CLI.
    bash -c "./project/deploy.sh -y --restore-www --restore-btcpay --backup-archive-path=$BTCPAY_RESTORE_ARCHIVE_PATH"

done