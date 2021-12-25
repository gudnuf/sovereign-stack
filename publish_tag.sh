#!/bin/bash

# this script will tag the repo then push it to origin
TAG_NAME=v0.0.14
COMIT_MESSAGE="Creating commit on $(date)."
TAG_MESSAGE="Creating tag $TAG_NAME on $(date)."

# create a git commit with staged changes.
git commit -m "$COMIT_MESSAGE" -s
git tag -a "$TAG_NAME" -m "$TAG_MESSAGE" -s

# optional; push to remote
git push --all
git push --tags
