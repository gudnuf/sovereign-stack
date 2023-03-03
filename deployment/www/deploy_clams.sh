#!/bin/bash

set -ex
cd "$(dirname "$0")"

# deploy clams wallet.
LOCAL_CLAMS_REPO_PATH="$(pwd)/www/clams"
if [ "$DEPLOY_BTCPAY_SERVER" = true ]; then
    if [ ! -d "$LOCAL_CLAMS_REPO_PATH" ]; then
        git clone "$CLAMS_GIT_REPO" "$LOCAL_CLAMS_REPO_PATH"
    else
        cd "$LOCAL_CLAMS_REPO_PATH"
        #git config pull.ff only
        git pull
        cd -
    fi
fi

lxc file push -r -p ./clams "${PRIMARY_WWW_FQDN//./-}"/home/ubuntu/code

# run the primary script and output the files to --output-path
ssh "$PRIMARY_WWW_FQDN" mkdir -p "$REMOTE_HOME/clams/browser-app"
ssh "$PRIMARY_WWW_FQDN" "$REMOTE_HOME/code/clams/browser-app/run.sh --output-path=$REMOTE_HOME/clams/browser-app"
ssh "$PRIMARY_WWW_FQDN" rm -rf "$REMOTE_HOME/code"
