#!/bin/bash

set -exu
cd "$(dirname "$0")"

# check if there are any uncommited changes. It's dangerous to 
# alter production systems when you have commits to make or changes to stash.
# if git update-index --refresh | grep -q "needs update"; then
#     echo "ERROR: You have uncommited changes! You MUST commit or stash all changes to continue."
#     exit 1
# fi

echo "WARNING: this script backs up your existing remote and saves all data locally in the SSME."
echo "         Then, all your VMs are destroyed on the remote resulting is destruction of user data."
echo "         But then we re-create everything using the new codebase, then restore user data to the"
echo "         newly provisioned VMs."

RESPONSE=
read -r -p "Are you sure you want to continue (y/n):  ": RESPONSE
if [ "$RESPONSE" != "y" ]; then
    echo "STOPPING."
    exit 0
fi


USER_TARGET_PROJECT=

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --project=*)
            USER_TARGET_PROJECT="${i#*=}"
            shift
        ;;

        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done


. ../defaults.sh

. ./remote_env.sh

for PROJECT_CHAIN in ${DEPLOYMENT_STRING//,/ }; do
    NO_PARENS="${PROJECT_CHAIN:1:${#PROJECT_CHAIN}-2}"
    PROJECT_PREFIX=$(echo "$NO_PARENS" | cut -d'|' -f1)
    BITCOIN_CHAIN=$(echo "$NO_PARENS" | cut -d'|' -f2)
    export PROJECT_PREFIX="$PROJECT_PREFIX"
    export BITCOIN_CHAIN="$BITCOIN_CHAIN"

    PROJECT_NAME="$PROJECT_PREFIX-$BITCOIN_CHAIN"
    PROJECT_PATH="$PROJECTS_DIR/$PROJECT_NAME"

    # if the user sets USER_TARGET_PROJECT, let's ensure the project exists.
    if [ -n "$USER_TARGET_PROJECT" ]; then
        if ! lxc project list | grep -q "$USER_TARGET_PROJECT"; then
            echo "ERROR: the project does not exist! Nothing to update."
            exit 1
        fi

        if [ "$PROJECT_NAME" != "$USER_TARGET_PROJECT" ]; then
            continue
        fi
    fi

    export PROJECT_NAME="$PROJECT_NAME"
    export PROJECT_PATH="$PROJECT_PATH"

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
    source "$SITE_PATH/site.conf"
    source ./project/domain_env.sh

    # now we want to switch the git HEAD of the project subdirectory to the 
    # version of code that was last used
    GIT_COMMIT_ON_REMOTE_HOST="$(ssh ubuntu@$BTCPAY_FQDN cat /home/ubuntu/.ss-githead)"
    cd project/
    echo "INFO: switch the 'project' repo to commit prior commit '$GIT_COMMIT_ON_REMOTE_HOST'"
    echo "      This allows Sovereign Stack to can grab a backup using the version of the code"
    echo "      that was used when the deployment was created."
    git checkout "$GIT_COMMIT_ON_REMOTE_HOST"
    cd -

    # run deploy which backups up everything, but doesnt restart any services.
    bash -c "./project/deploy.sh --project=$PROJECT_NAME --stop --no-cert-renew --backup-archive-path=$BTCPAY_RESTORE_ARCHIVE_PATH"

    # call the destroy script. If user proceed, then user data is DESTROYED!
    bash -c "./destroy.sh --project=$PROJECT_NAME"

    cd project/
    echo "INFO: switching the 'project' repo back to the most recent commit '$TARGET_PROJECT_GIT_COMMIT'"
    echo "      That way new deployments will be instantiated using the latest codebase."
    git checkout "$TARGET_PROJECT_GIT_COMMIT"
    cd -

    # Then we can run a restore operation and specify the backup archive at the CLI.
    bash -c "./project/deploy.sh --project=$PROJECT_NAME -y --restore-www --restore-btcpay --backup-archive-path=$BTCPAY_RESTORE_ARCHIVE_PATH"

done