#!/bin/bash

set -ex
cd "$(dirname "$0")"

# deploy clams wallet.
LOCAL_CLAMS_REPO_PATH="$(pwd)/clams"
BROWSER_APP_GIT_TAG="1.5.0"
BROWSER_APP_GIT_REPO_URL="https://github.com/clams-tech/browser-app"
if [ ! -d "$LOCAL_CLAMS_REPO_PATH" ]; then
    git clone "$BROWSER_APP_GIT_REPO_URL" "$LOCAL_CLAMS_REPO_PATH"
else
    cd "$LOCAL_CLAMS_REPO_PATH"
    git config --global pull.rebase false
    git pull
    cd -
fi

# lxc file push -r -p "$LOCAL_CLAMS_REPO_PATH" "${PRIMARY_WWW_FQDN//./-}$REMOTE_HOME"
BROWSER_APP_IMAGE_NAME="browser-app:$BROWSER_APP_GIT_TAG"
# build the browser-app image.
if ! docker image list --format "{{.Repository}}:{{.Tag}}" | grep -q "$BROWSER_APP_IMAGE_NAME"; then
    docker build --build-arg GIT_REPO_URL="$BROWSER_APP_GIT_REPO_URL" \
    --build-arg VERSION="$BROWSER_APP_GIT_TAG" \
    -t "$BROWSER_APP_IMAGE_NAME" \
    $(pwd)/clams/frontend/browser-app/
fi

# If the clams-root volume doesn't exist, we create and seed it.
if ! docker volume list | grep -q clams-root; then
    docker volume create clams-root
    docker run -t --rm -v clams-root:/output --name browser-app "$BROWSER_APP_IMAGE_NAME"
fi
