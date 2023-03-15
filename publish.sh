#!/bin/bash

set -eu
cd "$(dirname "$0")"

# this script will tag the repo then push it to origin
TAG_NAME="$(head -n 1 ./version.txt)"
TAG_MESSAGE="Creating tag $TAG_NAME on $(date)."

# create the git tag.
if ! git tag | grep -q "$TAG_NAME"; then
    git tag -a "$TAG_NAME" -m "$TAG_MESSAGE" -s
fi

## note this will only work if you have permissions to update HEAD on https://git.sovereign-stack.org/ss/sovereign-stack.git
RESPONSE=
read -r -p "         Would you like to push this to the main Sovereign Stack repo? (y)  ": RESPONSE
if [ "$RESPONSE" = "y" ]; then
    # optional; push to remote
    git push --set-upstream origin --all
    git push --set-upstream origin --tags
fi
