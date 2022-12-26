#!/bin/bash

set -exu
cd "$(dirname "$0")"

# this script will tag the repo then push it to origin
TAG_NAME="$(head -n 1 ./version.txt)"
TAG_MESSAGE="Creating tag $TAG_NAME on $(date)."

git tag -a "$TAG_NAME" -m "$TAG_MESSAGE" -s

# optional; push to remote
git push --all
git push --tags
