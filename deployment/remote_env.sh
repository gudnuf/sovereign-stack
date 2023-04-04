#!/bin/bash

set -eu
cd "$(dirname "$0")"

CURRENT_REMOTE="$(lxc remote get-default)"

if echo "$CURRENT_REMOTE" | grep -q "production"; then
    echo "WARNING: You are running a migration procedure on a production system."
    echo ""


    RESPONSE=
    read -r -p "         Are you sure you want to continue (y)  ": RESPONSE
    if [ "$RESPONSE" != "y" ]; then
        echo "STOPPING."
        exit 1
    fi

    # check if there are any uncommited changes. It's dangerous to 
    # alter production systems when you have commits to make or changes to stash.
    if git update-index --refresh | grep -q "needs update"; then
        echo "ERROR: You have uncommited changes! Better stash your work with 'git stash'."
        exit 1
    fi

fi

export REMOTE_PATH="$REMOTES_PATH/$CURRENT_REMOTE"
REMOTE_DEFINITION="$REMOTE_PATH/remote.conf"
export REMOTE_DEFINITION="$REMOTE_DEFINITION"

# ensure the remote definition exists.
if [ ! -f "$REMOTE_DEFINITION" ]; then
    echo "ERROR: The remote definition could not be found. You may need to run 'ss-remote'."
    echo "INFO: Consult https://www.sovereign-stack.org/ss-remote for more information."
    exit 1
fi

source "$REMOTE_DEFINITION"
