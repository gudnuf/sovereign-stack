#!/bin/bash


domain_number=0
for DOMAIN_NAME in ${DOMAIN_LIST//,/ }; do
    export DOMAIN_NAME="$DOMAIN_NAME"
    export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"


    # source the site path so we know what features it has.
    source ../../reset_env.sh
    source "$SITE_PATH/site_definition"
    source ../../domain_env.sh

    # for each language specified in the site_definition, we spawn a separate ghost container
    # at https://www.domain.com/$LANGUAGE_CODE
    for LANGUAGE_CODE in ${SITE_LANGUAGE_CODES//,/ }; do
        STACK_NAME="$DOCKER_STACK_SUFFIX-$LANGUAGE_CODE"

        # ensure directories on remote host exist so we can mount them into the containers.
        ssh "$PRIMARY_WWW_FQDN" mkdir -p "$REMOTE_HOME/ghost/$DOMAIN_NAME/$LANGUAGE_CODE/ghost" "$REMOTE_HOME/ghost/$DOMAIN_NAME/$LANGUAGE_CODE/db"

        export GHOST_STACK_TAG="ghost-$STACK_NAME"
        export GHOST_DB_STACK_TAG="ghostdb-$STACK_NAME"

        # todo append domain number or port number.
        WEBSTACK_PATH="$SITE_PATH/webstack"
        mkdir -p "$WEBSTACK_PATH"
        export DOCKER_YAML_PATH="$WEBSTACK_PATH/ghost-$LANGUAGE_CODE.yml"

        # here's the NGINX config. We support ghost and nextcloud.
        echo "" > "$DOCKER_YAML_PATH"
        cat >>"$DOCKER_YAML_PATH" <<EOL
version: "3.8"
services:

EOL
    # This is the ghost for HTTPS (not over Tor)
        cat >>"$DOCKER_YAML_PATH" <<EOL
  ${GHOST_STACK_TAG}:
    image: ${GHOST_IMAGE}
    networks:
      - ghostnet-${DOCKER_STACK_SUFFIX}-${LANGUAGE_CODE}
      - ghostdbnet-${DOCKER_STACK_SUFFIX}-${LANGUAGE_CODE}
    volumes:
      - ${REMOTE_HOME}/ghost/${DOMAIN_NAME}/${LANGUAGE_CODE}/ghost:/var/lib/ghost/content
    environment:
EOL

            cat >>"$DOCKER_YAML_PATH" <<EOL
      - url=https://${WWW_FQDN}/${LANGUAGE_CODE}
      - database__client=mysql
      - database__connection__host=${GHOST_DB_STACK_TAG}
      - database__connection__user=ghost
      - database__connection__password=\${GHOST_MYSQL_PASSWORD}
      - database__connection__database=ghost
      - database__pool__min=0
      - privacy__useStructuredData=true
    deploy:
      restart_policy:
        condition: on-failure

  ${GHOST_DB_STACK_TAG}:
    image: ${GHOST_DB_IMAGE}
    networks:
      - ghostdbnet-${DOCKER_STACK_SUFFIX}-${LANGUAGE_CODE}
    volumes:
      - ${REMOTE_HOME}/ghost/${DOMAIN_NAME}/${LANGUAGE_CODE}/db:/var/lib/mysql
    environment:
       - MYSQL_ROOT_PASSWORD=\${GHOST_MYSQL_ROOT_PASSWORD}
       - MYSQL_DATABASE=ghost
       - MYSQL_USER=ghost
       - MYSQL_PASSWORD=\${GHOST_MYSQL_PASSWORD}
    deploy:
      restart_policy:
        condition: on-failure

EOL

        cat >>"$DOCKER_YAML_PATH" <<EOL
networks:
EOL

        if [ "$DEPLOY_GHOST" = true ]; then
            GHOSTNET_NAME="ghostnet-$DOCKER_STACK_SUFFIX-$LANGUAGE_CODE"
            GHOSTDBNET_NAME="ghostdbnet-$DOCKER_STACK_SUFFIX-$LANGUAGE_CODE"

            cat >>"$DOCKER_YAML_PATH" <<EOL
    ${GHOSTNET_NAME}:
      name: "reverse-proxy_ghostnet-$DOCKER_STACK_SUFFIX-$LANGUAGE_CODE"
      external: true

    ${GHOSTDBNET_NAME}:
EOL
        fi

        docker stack deploy -c "$DOCKER_YAML_PATH" "$DOCKER_STACK_SUFFIX-$LANGUAGE_CODE"
        sleep 1
    done
    
    domain_number=$((domain_number+1))
done
