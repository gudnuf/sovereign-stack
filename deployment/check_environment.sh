#!/bin/bash

set -ex

if lxc remote get-default | grep -q "production"; then
    echo "WARNING: You are running a migration procedure on a production system."
    echo ""

    # check if there are any uncommited changes. It's dangerous to 
    # alter production systems when you have commits to make or changes to stash.
    if git update-index --refresh | grep -q "needs update"; then
        echo "ERROR: You have uncommited changes! You MUST commit or stash all changes to continue."
        exit 1
    fi

    RESPONSE=
    read -r -p "         Are you sure you want to continue (y)  ": RESPONSE
    if [ "$RESPONSE" != "y" ]; then
        echo "STOPPING."
        exit 1
    fi

fi
