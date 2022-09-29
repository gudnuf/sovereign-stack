#!/bin/bash

set -exu
cd "$(dirname "$0")"

for DOMAIN_NAME in ${DOMAIN_LIST//,/ }; do
    export DOMAIN_NAME="$DOMAIN_NAME"
    export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"

    # source the site path so we know what features it has.
    source ../../../reset_env.sh
    source "$SITE_PATH/site_definition"
    source ../../../domain_env.sh

    if [ "$DEPLOY_GITEA" = true ]; then
        GITEA_PATH="$REMOTE_GITEA_PATH/$DOMAIN_NAME/${LANGUAGE_CODE}"

        ssh "$PRIMARY_WWW_FQDN" mkdir -p "$GITEA_PATH"

        STACK_NAME="$DOCKER_STACK_SUFFIX-$LANGUAGE_CODE"

        export STACK_TAG="gitea-$STACK_NAME"
        export DB_STACK_TAG="giteadb-$STACK_NAME"

        # todo append domain number or port number.
        WEBSTACK_PATH="$SITE_PATH/webstack"
        mkdir -p "$WEBSTACK_PATH" "$WEBSTACK_PATH/data" "$WEBSTACK_PATH/db"
        export DOCKER_YAML_PATH="$WEBSTACK_PATH/gitea-en.yml"

        NET_NAME="giteanet-$DOCKER_STACK_SUFFIX"
        DBNET_NAME="giteadbnet-$DOCKER_STACK_SUFFIX"

        # here's the NGINX config. We support ghost and nextcloud.
        echo "" > "$DOCKER_YAML_PATH"
        cat >>"$DOCKER_YAML_PATH" <<EOL
version: "3.8"
services:

  ${STACK_TAG}:
    image: ${GITEA_IMAGE}
    volumes:
      - ${GITEA_PATH}/data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - ROOT_URL=https://${GITEA_FQDN}
      - GITEA__database__DB_TYPE=mysql
      - GITEA__database__HOST=${DB_STACK_TAG}:3306
      - GITEA__database__NAME=gitea
      - GITEA__database__USER=gitea
      - GITEA__PASSWD=\${GITEA_MYSQL_PASSWORD}
    networks:
      - ${NET_NAME}
      - ${DBNET_NAME}
    deploy:
      restart_policy:
        condition: on-failure

  ${DB_STACK_TAG}:
    image: ${GITEA_DB_IMAGE}
    networks:
      - ${DBNET_NAME}
    volumes:
      - ${GITEA_PATH}/db:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=\${GITEA_MYSQL_ROOT_PASSWORD}
      - MYSQL_PASSWORD=\${GITEA_MYSQL_PASSWORD}
      - MYSQL_DATABASE=gitea
      - MYSQL_USER=gitea
    deploy:
      restart_policy:
        condition: on-failure

networks:
EOL

        cat >>"$DOCKER_YAML_PATH" <<EOL
    ${NET_NAME}:
      name: "reverse-proxy_${NET_NAME}-${LANGUAGE_CODE}"
      external: true

    ${DBNET_NAME}:
EOL

        docker stack deploy -c "$DOCKER_YAML_PATH" "$DOCKER_STACK_SUFFIX-gitea-$LANGUAGE_CODE"
        sleep 1
    
    fi

done
