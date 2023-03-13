#!/bin/bash

set -eu
cd "$(dirname "$0")"

# source project defition.
# Now let's load the project definition.
PROJECT_NAME="$PROJECT_PREFIX-$BITCOIN_CHAIN"
export PROJECT_NAME="$PROJECT_NAME"
PROJECT_PATH="$PROJECTS_DIR/$PROJECT_NAME"
export PROJECT_PATH="$PROJECT_PATH"
PROJECT_DEFINITION_PATH="$PROJECT_PATH/project.conf"

if [ ! -f "$PROJECT_DEFINITION_PATH" ]; then
    echo "ERROR: 'project.conf' not found $PROJECT_DEFINITION_PATH not found."
    exit 1
fi

source "$PROJECT_DEFINITION_PATH"

export PRIMARY_SITE_DEFINITION_PATH="$SITES_PATH/$PRIMARY_DOMAIN/site.conf"

if [ ! -f "$PRIMARY_SITE_DEFINITION_PATH" ]; then
    echo "ERROR: the site definition does not exist."
    exit 1
fi

if [ -z "$PRIMARY_DOMAIN" ]; then
    echo "ERROR: The PRIMARY_DOMAIN is not specified. Check your remote definition at '$PRIMARY_SITE_DEFINITION_PATH'."
    exit 1
fi

source "$PRIMARY_SITE_DEFINITION_PATH"