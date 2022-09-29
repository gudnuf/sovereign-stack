#!/bin/bash

set -exu
cd "$(dirname "$0")"

# bring down ghost instances.
for DOMAIN_NAME in ${DOMAIN_LIST//,/ }; do
    export DOMAIN_NAME="$DOMAIN_NAME"
    export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"

    # source the site path so we know what features it has.
    source ../../reset_env.sh
    source "$SITE_PATH/site_definition"
    source ../../domain_env.sh

    ### Stop all services.
    for APP in ghost gitea; do
        # backup each language for each app.
        for LANGUAGE_CODE in ${SITE_LANGUAGE_CODES//,/ }; do
            STACK_NAME="$DOCKER_STACK_SUFFIX-$APP-$LANGUAGE_CODE"

            if docker stack list --format "{{.Name}}" | grep -q "$STACK_NAME"; then
                docker stack rm "$STACK_NAME"
                sleep 2
            fi

            ./backup_path.sh "$APP"
        done
    done
done


if docker stack list --format "{{.Name}}" | grep -q reverse-proxy; then
    docker stack rm reverse-proxy

    # wait for all docker containers to stop.
    # TODO see if there's a way to check for this.
    sleep 10
fi

# generate the certs and grab a backup
if [ "$RUN_CERT_RENEWAL" = true ]; then
    ./generate_certs.sh
fi

if [ "$BACKUP_CERTS" = true ]; then
    # Back each domain's certificates under /home/ubuntu/letsencrypt/domain
    for DOMAIN_NAME in ${DOMAIN_LIST//,/ }; do
        export DOMAIN_NAME="$DOMAIN_NAME"
        export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"

        # source the site path so we know what features it has.
        source ../../reset_env.sh
        source "$SITE_PATH/site_definition"
        source ../../domain_env.sh

        ./backup_path.sh "letsencrypt"
    done

fi
