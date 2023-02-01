#!/bin/bash

set -ex
cd "$(dirname "$0")"

docker pull "$NOSTR_RELAY_IMAGE"

for DOMAIN_NAME in ${DOMAIN_LIST//,/ }; do
    export DOMAIN_NAME="$DOMAIN_NAME"
    export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"

    # source the site path so we know what features it has.
    source ../../../defaults.sh
    source "$SITE_PATH/site_definition"
    source ../../domain_env.sh

    if [ -n "$NOSTR_ACCOUNT_PUBKEY" ]; then
        REMOTE_NOSTR_PATH="$REMOTE_HOME/nostr"
        NOSTR_PATH="$REMOTE_NOSTR_PATH/$DOMAIN_NAME"
        NOSTR_CONFIG_PATH="$SITE_PATH/webstack/nostr.config"

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
    configs:
      - source: nostr-config
        target: /usr/src/app/config.toml
    deploy:
      restart_policy:
        condition: on-failure

networks:
  ${NET_NAME}:
    name: "reverse-proxy_${NET_NAME}-en"
    external: true

configs:
  nostr-config:
    file: ${NOSTR_CONFIG_PATH}
EOL

        # documentation: https://git.sr.ht/~gheartsfield/nostr-rs-relay/tree/0.7.0/item/config.toml
        cat >"$NOSTR_CONFIG_PATH" <<EOL
[info]
relay_url = "wss://${NOSTR_FQDN}/"
name = "${NOSTR_FQDN}"
description = "A nostr relay for ${DOMAIN_NAME} whitelisted for pubkey ${NOSTR_ACCOUNT_PUBKEY}."
pubkey = "${NOSTR_ACCOUNT_PUBKEY}"
contact = "mailto:${CERTIFICATE_EMAIL_ADDRESS}"

[options]
reject_future_seconds = 1800

[limits]
#messages_per_sec = 3
#max_event_bytes = 131072
#max_ws_message_bytes = 131072
#max_ws_frame_bytes = 131072
#broadcast_buffer = 16384
#event_persist_buffer = 4096

[authorization]
# Pubkey addresses in this array are whitelisted for event publishing.
# Only valid events by these authors will be accepted, if the variable
# is set.
pubkey_whitelist = [ "${NOSTR_ACCOUNT_PUBKEY}" ]
domain_whitelist = [ "${DOMAIN_NAME}" ]
EOL

        if [ "$STOP_SERVICES" = false ]; then
            docker stack deploy -c "$DOCKER_YAML_PATH" "$DOMAIN_IDENTIFIER-nostr-$LANGUAGE_CODE"
            sleep 1
        fi
    
    fi

done
