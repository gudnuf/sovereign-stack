#!/bin/bash

set -exu
cd "$(dirname "$0")"

# this script will tag the repo then push it to origin
TAG_NAME="$(head -n 1 ./version.txt)"
TAG_MESSAGE="Creating tag $TAG_NAME on $(date)."

git tag -a "$TAG_NAME" -m "$TAG_MESSAGE" -s

# optional; push to remote
git push --set-upstream origin --all
git push --set-upstream origin --tags

RESPONSE=
read -r -p "         Would you like to push this to the main ss repo? (y)  ": RESPONSE
if [ "$RESPONSE" != "y" ]; then
    # optional; push to remote
    git push --set-upstream ss-upstream --all
    git push --set-upstream ss-upstream --tags
fi
