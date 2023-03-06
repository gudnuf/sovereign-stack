#!/bin/bash

set -exu
cd "$(dirname "$0")"

# this script will tag the repo then push it to origin
TAG_NAME="$(head -n 1 ./version.txt)"
TAG_MESSAGE="Creating tag $TAG_NAME on $(date)."

git tag -a "$TAG_NAME" -m "$TAG_MESSAGE" -s

# push commits and tags to origin
git push --set-upstream origin --all
git push --set-upstream origin --tags

## note this will only work if you have permissions to update HEAD on https://git.sovereign-stack.org/ss/sovereign-stack.git
RESPONSE=
read -r -p "         Would you like to push this to the main Sovereign Stack repo? (y)  ": RESPONSE
if [ "$RESPONSE" != "y" ]; then
    # optional; push to remote
    git push --set-upstream ss-upstream --all
    git push --set-upstream ss-upstream --tags
fi
