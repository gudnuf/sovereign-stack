#!/bin/bash

set -exu
cd "$(dirname "$0")"

TARGET_PROJECT_GIT_COMMIT=2e68e93303196fd57b1b473b149b5a82c9faa4f0

# # As part of the install script, we pull down any other sovereign-stack git repos
# PROJECTS_SCRIPTS_REPO_URL="https://git.sovereign-stack.org/ss/project"
# PROJECTS_SCRIPTS_PATH="$(pwd)/deployment/project"
# if [ ! -d "$PROJECTS_SCRIPTS_PATH" ]; then
#     git clone "$PROJECTS_SCRIPTS_REPO_URL" "$PROJECTS_SCRIPTS_PATH"
# else
#     cd "$PROJECTS_SCRIPTS_PATH" || exit 1
#     git -c advice.detachedHead=false pull origin main
#     git checkout "$TARGET_PROJECT_GIT_COMMIT"
#     cd - || exit 1
# fi

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

. ./deployment_defaults.sh

. ./remote_env.sh

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


# first, let's grab the GIT commit from the remote machine.
export DOMAIN_NAME="$PRIMARY_DOMAIN"
export SITE_PATH="$SITES_PATH/$PRIMARY_DOMAIN"

# source the site path so we know what features it has.
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
bash -c "./up.sh --stop --backup-archive-path=$BTCPAY_RESTORE_ARCHIVE_PATH --backup-www --backup-btcpayserver --skip-base-image"

# call the down script (be default it is non-destructuve of user data.)
./down.sh


next we switch back to the current version of Sovereign Stack scripts for bringin up the new version.
cd project/
echo "INFO: switching the 'project' repo back to the most recent commit '$TARGET_PROJECT_GIT_COMMIT'"
echo "      That way new deployments will be instantiated using the latest codebase."
git checkout "$TARGET_PROJECT_GIT_COMMIT"
cd -


# TODO we can do some additional logic here. FOr example if the user wants to provide a source/target project/remote,
# we can backup the source remote+project and restore it to the target remote+project. This will facilitate cross-device migrations

# However, if the source and target project/remote are the same, we don't really
# need to do any restorations (or backups for that matter, though we still grab one);
# we simply mount the existing data. That's the more common case where the user is simply upgrading the system in-place.

./up.sh
