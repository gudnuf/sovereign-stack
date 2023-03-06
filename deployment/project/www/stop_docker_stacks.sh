#!/bin/bash

set -eu
cd "$(dirname "$0")"

# bring down ghost instances.
for DOMAIN_NAME in ${DOMAIN_LIST//,/ }; do
    export DOMAIN_NAME="$DOMAIN_NAME"
    export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"

    # source the site path so we know what features it has.
    source ../../../defaults.sh
    source "$SITE_PATH/site_definition"
    source ../domain_env.sh

    ### Stop all services.
    for APP in ghost nextcloud gitea nostr; do
        # backup each language for each app.
        for LANGUAGE_CODE in ${SITE_LANGUAGE_CODES//,/ }; do
            STACK_NAME="$DOMAIN_IDENTIFIER-$APP-$LANGUAGE_CODE"

            if docker stack list --format "{{.Name}}" | grep -q "$STACK_NAME"; then
                docker stack rm "$STACK_NAME"
                sleep 2
            fi

            # these variable are used by both backup/restore scripts.
            export APP="$APP"
            export REMOTE_BACKUP_PATH="$REMOTE_HOME/backups/www/$APP/$DOMAIN_IDENTIFIER-$LANGUAGE_CODE"
            export REMOTE_SOURCE_BACKUP_PATH="$REMOTE_HOME/$APP/$DOMAIN_NAME"
  
            # ensure our local backup path exists so we can pull down the duplicity archive to the management machine.
            export LOCAL_BACKUP_PATH="$SITE_PATH/backups/www/$APP"

            # ensure our local backup path exists.
            if [ ! -d "$LOCAL_BACKUP_PATH" ]; then
                mkdir -p "$LOCAL_BACKUP_PATH"
            fi

            if [ "$RESTORE_WWW" = true ]; then
                ./restore_path.sh
                #ssh "$PRIMARY_WWW_FQDN" sudo chown ubuntu:ubuntu "$REMOTE_HOME/$APP"
            elif [ "$BACKUP_APPS"  = true ]; then
                # if we're not restoring, then we may or may not back up.
                ./backup_path.sh
            fi
        done
    done
done
