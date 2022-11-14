#!/bin/bash

set -exu
cd "$(dirname "$0")"

for DOMAIN_NAME in ${DOMAIN_LIST//,/ }; do
    export DOMAIN_NAME="$DOMAIN_NAME"
    export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"

    # source the site path so we know what features it has.
    source "$RESPOSITORY_PATH/reset_env.sh"
    source "$SITE_PATH/site_definition"
    source "$RESPOSITORY_PATH/domain_env.sh"

    if [ "$DEPLOY_NOSTR_RELAY" = true ]; then
        REMOTE_NOSTR_PATH="$REMOTE_HOME/nostr"
        NOSTR_PATH="$REMOTE_NOSTR_PATH/$DOMAIN_NAME"

        ssh "$PRIMARY_WWW_FQDN" mkdir -p "$NOSTR_PATH/data" "$NOSTR_PATH/db"

        export STACK_TAG="nostr-$DOMAIN_IDENTIFIER"
        export DOCKER_YAML_PATH="$SITE_PATH/webstack/nostr.yml"

        NET_NAME="nostrnet-$DOMAIN_IDENTIFIER"
        DBNET_NAME="nostrdbnet-$DOMAIN_IDENTIFIER"

        # here's the NGINX config. We support ghost and nextcloud.
        echo "" > "$DOCKER_YAML_PATH"
        cat >>"$DOCKER_YAML_PATH" <<EOL
version: "3.8"
services:

  ${STACK_TAG}:
    image: ${NOSTR_RELAY_IMAGE}
    volumes:
      - ${NOSTR_PATH}/data:/usr/src/app/db
    # environment:
    #   - USER_UID=1000
    networks:
      - ${NET_NAME}
    deploy:
      restart_policy:
        condition: on-failure

networks:
    ${NET_NAME}:
      name: "reverse-proxy_${NET_NAME}"
      external: true

EOL

        docker pull "$NOSTR_RELAY_IMAGE"
        docker stack deploy -c "$DOCKER_YAML_PATH" "$DOMAIN_IDENTIFIER-nostr"
        sleep 1
    
    fi

done
