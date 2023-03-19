#!/bin/bash

set -e
cd "$(dirname "$0")"

# this script destroys all resources in the current project.

if lxc remote get-default | grep -q "local"; then
    echo "ERROR: you are on the local lxc remote. Nothing to destroy"
    exit 1
fi

echo "WARNING: This will DESTROY any existing VMs! Use the --purge flag to delete ALL Sovereign Stack LXD resources."

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

    PROJECT_NAME="$PROJECT_PREFIX-$BITCOIN_CHAIN"
    PROJECT_PATH="$PROJECTS_DIR/$PROJECT_NAME"

    # if the user sets USER_TARGET_PROJECT, let's ensure the project exists.
    if [ -n "$USER_TARGET_PROJECT" ]; then
        if ! lxc project list | grep -q "$USER_TARGET_PROJECT"; then
            echo "ERROR: the project does not exist! Nothing to destroy."
            exit 1
        fi

        if [ "$PROJECT_NAME" != "$USER_TARGET_PROJECT" ]; then
            echo "INFO: Skipping project '$PROJECT_NAME' since the system owner has used the --project= switch."
            exit
        fi
    fi

    export PROJECT_NAME="$PROJECT_NAME"
    export PROJECT_PATH="$PROJECT_PATH"

    . ./project_env.sh

    if ! lxc info | grep "project:" | grep -q "$PROJECT_NAME"; then
        if lxc project list | grep -q "$PROJECT_NAME"; then
            lxc project switch "$PROJECT_NAME"
        fi
    fi

    for VM in www btcpayserver; do
        LXD_NAME="$VM-${DOMAIN_NAME//./-}"

        if lxc list | grep -q "$LXD_NAME"; then
            lxc delete -f "$LXD_NAME"

            # remove the ssh known endpoint else we get warnings.
            ssh-keygen -f "$SSH_HOME/known_hosts" -R "$LXD_NAME"
        fi

        if lxc profile list | grep -q "$LXD_NAME"; then
            lxc profile delete "$LXD_NAME"
        fi
    done

    if lxc network list -q | grep -q ss-ovn; then
        lxc network delete ss-ovn
    fi

    if ! lxc info | grep "project:" | grep -q default; then
        lxc project switch default
    fi

    if lxc project list | grep -q "$PROJECT_NAME"; then
        lxc project delete "$PROJECT_NAME"
    fi

    # delete the base image so it can be created.
    if lxc list | grep -q "$BASE_IMAGE_VM_NAME"; then
        lxc delete -f "$BASE_IMAGE_VM_NAME"
        # remove the ssh known endpoint else we get warnings.
        ssh-keygen -f "$SSH_HOME/known_hosts" -R "$LXD_NAME"
    fi
done