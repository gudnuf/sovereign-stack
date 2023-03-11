#!/bin/bash

set -eu
cd "$(dirname "$0")"

# source project defition.
# Now let's load the project definition.
PROJECT_NAME="$PROJECT_PREFIX-$BITCOIN_CHAIN"
export PROJECT_NAME="$PROJECT_NAME"
PROJECT_PATH="$PROJECTS_DIR/$PROJECT_NAME"
PROJECT_DEFINITION_PATH="$PROJECT_PATH/project_definition"

if [ ! -f "$PROJECT_DEFINITION_PATH" ]; then
    echo "ERROR: 'project_definition' not found $PROJECT_DEFINITION_PATH not found."
    exit 1
fi

source "$PROJECT_DEFINITION_PATH"
export PRIMARY_SITE_DEFINITION_PATH="$SITES_PATH/$PRIMARY_DOMAIN/site_definition"
source "$PRIMARY_SITE_DEFINITION_PATH"

if [ -z "$PRIMARY_DOMAIN" ]; then
    echo "ERROR: The PRIMARY_DOMAIN is not specified. Check your remote definition at '$PRIMARY_SITE_DEFINITION_PATH'."
    exit 1
fi
