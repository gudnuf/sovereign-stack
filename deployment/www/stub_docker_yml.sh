#!/bin/bash

set -eux
cd "$(dirname "$0")"




ssh "$PRIMARY_WWW_FQDN" sudo rm -rf /home/ubuntu/ghost
sleep 4


#https://github.com/fiatjaf/expensive-relay
# NOSTR RELAY WHICH REQUIRES PAYMENTS.
DOCKER_YAML_PATH="$PROJECT_PATH/nginx.yml"
cat > "$DOCKER_YAML_PATH" <<EOL
version: "3.8"
services:

  nginx:
    image: ${NGINX_IMAGE}
    ports:
      - 0.0.0.0:443:443
      - 0.0.0.0:80:80
    networks:
EOL

    for i in $(seq 0 $DOMAIN_COUNT); do
        cat >> "$DOCKER_YAML_PATH" <<EOL
        - ghostnet-$i
EOL
    done

        cat >> "$DOCKER_YAML_PATH" <<EOL
    volumes:
      - ${REMOTE_HOME}/letsencrypt:/etc/letsencrypt:ro
    configs:
      - source: nginx-config
        target: /etc/nginx/nginx.conf
    deploy:
      restart_policy:
        condition: on-failure
        
configs:
  nginx-config:
    file: ${PROJECT_PATH}/nginx.conf

EOL

    cat >> "$DOCKER_YAML_PATH" <<EOL
networks:
EOL

    for i in $(seq 0 $DOMAIN_COUNT); do
        cat >> "$DOCKER_YAML_PATH" <<EOL
  ghostnet-$i:
    attachable: true

EOL
    done


docker stack deploy -c "$DOCKER_YAML_PATH" "reverse-proxy"


# iterate over all our domains and create the nginx config file.


domain_number=0
for DOMAIN_NAME in ${DOMAIN_LIST//,/ }; do
    export DOMAIN_NAME="$DOMAIN_NAME"
    export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"

    ssh "$PRIMARY_WWW_FQDN" mkdir -p "$REMOTE_HOME/ghost/$DOMAIN_NAME/ghost" "$REMOTE_HOME/ghost/$DOMAIN_NAME/db"

    # source the site path so we know what features it has.
    source ../../reset_env.sh
    source "$SITE_PATH/site_definition"
    source ../../domain_env.sh

    STACK_TAG="ghost-$domain_number"

    # todo append domain number or port number.
    mkdir -p "$SITE_PATH/webstack"
    DOCKER_YAML_PATH="$SITE_PATH/webstack/$STACK_TAG.yml"
    export DOCKER_YAML_PATH="$DOCKER_YAML_PATH"
    # if [ "$DEPLOY_ONION_SITE" = true ]; then
    #     if [ -z "$ONION_ADDRESS" ]; then
    #         echo "ERROR: ONION_ADDRESS is not defined."
    #         exit 1
    #     fi
    # fi

    # here's the NGINX config. We support ghost and nextcloud.
    echo "" > "$DOCKER_YAML_PATH"

    cat >>"$DOCKER_YAML_PATH" <<EOL
version: "3.8"
services:

EOL


    # This is the ghost for HTTPS (not over Tor)
    cat >>"$DOCKER_YAML_PATH" <<EOL
  ghost-${domain_number}:
    image: ${GHOST_IMAGE}
    networks:
      - ghostnet-${domain_number}
      - ghostdbnet-${domain_number}
    volumes:
      - ${REMOTE_HOME}/ghost/${DOMAIN_NAME}/ghost:/var/lib/ghost/content
    environment:
      - url=https://${PRIMARY_WWW_FQDN}
      - database__client=mysql
      - database__connection__host=ghostdb-${domain_number}
      - database__connection__user=ghost
      - database__connection__password=\${GHOST_MYSQL_PASSWORD}
      - database__connection__database=ghost
      - database__pool__min=0
      - privacy__useStructuredData=true
    deploy:
      restart_policy:
        condition: on-failure

  ghostdb-${domain_number}:
    image: ${GHOST_DB_IMAGE}
    networks:
      - ghostdbnet-${domain_number}
    volumes:
      - ${REMOTE_HOME}/ghost/${DOMAIN_NAME}/db:/var/lib/mysql
    environment:
       - MYSQL_ROOT_PASSWORD=\${GHOST_MYSQL_ROOT_PASSWORD}
       - MYSQL_DATABASE=ghost
       - MYSQL_USER=ghost
       - MYSQL_PASSWORD=\${GHOST_MYSQL_PASSWORD}
    deploy:
      restart_policy:
        condition: on-failure

EOL


#     if [ "$DEPLOY_NEXTCLOUD" = true ]; then
#         cat >>"$DOCKER_YAML_PATH" <<EOL
#   nextcloud-db:
#     image: ${NEXTCLOUD_DB_IMAGE}
#     command: --transaction-isolation=READ-COMMITTED --binlog-format=ROW --innodb_read_only_compressed=OFF
#     networks:
#       - nextclouddb-net
#     volumes:
#       - ${REMOTE_HOME}/nextcloud/db/data:/var/lib/mysql
#     environment:
#       - MARIADB_ROOT_PASSWORD=\${NEXTCLOUD_MYSQL_ROOT_PASSWORD}
#       - MYSQL_PASSWORD=\${NEXTCLOUD_MYSQL_PASSWORD}
#       - MYSQL_DATABASE=nextcloud
#       - MYSQL_USER=nextcloud
#     deploy:
#       restart_policy:
#         condition: on-failure

#   nextcloud:
#     image: ${NEXTCLOUD_IMAGE}
#     networks:
#       - nextclouddb-net
#       - nextcloud-net
#     volumes:
#       - ${REMOTE_HOME}/nextcloud/html:/var/www/html
#     environment:
#       - MYSQL_PASSWORD=\${NEXTCLOUD_MYSQL_PASSWORD}
#       - MYSQL_DATABASE=nextcloud
#       - MYSQL_USER=nextcloud
#       - MYSQL_HOST=nextcloud-db
#       - NEXTCLOUD_TRUSTED_DOMAINS=${DOMAIN_NAME}
#       - OVERWRITEHOST=${NEXTCLOUD_FQDN}
#       - OVERWRITEPROTOCOL=https
#       - SERVERNAME=${NEXTCLOUD_FQDN}
#     deploy:
#       restart_policy:
#         condition: on-failure

# EOL
#     fi

#     if [ "$DEPLOY_GITEA" = true ]; then
#         cat >>"$DOCKER_YAML_PATH" <<EOL
#   gitea:
#     image: ${GITEA_IMAGE}
#     volumes:
#       - ${REMOTE_GITEA_PATH}/data:/data
#       - /etc/timezone:/etc/timezone:ro
#       - /etc/localtime:/etc/localtime:ro
#     environment:
#       - USER_UID=1000
#       - USER_GID=1000
#       - ROOT_URL=https://${GITEA_FQDN}
#       - GITEA__database__DB_TYPE=mysql
#       - GITEA__database__HOST=gitea-db:3306
#       - GITEA__database__NAME=gitea
#       - GITEA__database__USER=gitea
#       - GITEA__PASSWD=\${GITEA_MYSQL_PASSWORD}
#     networks:
#       - gitea-net
#       - giteadb-net
#     deploy:
#       restart_policy:
#         condition: on-failure

#   gitea-db:
#     image: ${GITEA_DB_IMAGE}
#     networks:
#       - giteadb-net
#     volumes:
#       - ${REMOTE_GITEA_PATH}/db:/var/lib/mysql
#     environment:
#       - MYSQL_ROOT_PASSWORD=\${GITEA_MYSQL_ROOT_PASSWORD}
#       - MYSQL_PASSWORD=\${GITEA_MYSQL_PASSWORD}
#       - MYSQL_DATABASE=gitea
#       - MYSQL_USER=gitea
#     deploy:
#       restart_policy:
#         condition: on-failure
# EOL
#     fi



#     if [ "$DEPLOY_ONION_SITE" = true ]; then
#         cat >>"$DOCKER_YAML_PATH" <<EOL
#   # a hidden service that routes to the nginx container at http://onionurl.onion server block
#   tor-onion:
#     image: tor:latest
#     networks:
#       - tor-net
#     volumes:
#       - ${REMOTE_HOME}/tor:/var/lib/tor
#       - tor-logs:/var/log/tor
#     configs:
#       - source: tor-config
#         target: /etc/tor/torrc
#         mode: 0644
#     deploy:
#       mode: replicated
#       replicas: 1
#       restart_policy:
#         condition: on-failure

#   tor-ghost:
#     image: ${GHOST_IMAGE}
#     networks:
#       - ghostdb-net
#       - ghost-net
#     volumes:
#       - ${REMOTE_HOME}/tor_ghost:/var/lib/ghost/content
#     environment:
#       - url=https://${ONION_ADDRESS}
#       - database__client=mysql
#       - database__connection__host=ghostdb
#       - database__connection__user=ghost
#       - database__connection__password=\${GHOST_MYSQL_PASSWORD}
#       - database__connection__database=ghost
#     deploy:
#       restart_policy:
#         condition: on-failure

# EOL
#     fi


#     if [ "$DEPLOY_ONION_SITE" = true ]; then
# cat >>"$DOCKER_YAML_PATH" <<EOL
#       - torghost-net
# EOL
#     fi

#     if [ "$DEPLOY_NEXTCLOUD" = true ]; then
# cat >>"$DOCKER_YAML_PATH" <<EOL
#       - nextcloud-net
# EOL
#     fi

#     if [ "$DEPLOY_GITEA" = true ]; then
# cat >>"$DOCKER_YAML_PATH" <<EOL
#       - gitea-net
# EOL
#     fi

#     if [ "$DEPLOY_ONION_SITE" = true ]; then
# cat >>"$DOCKER_YAML_PATH" <<EOL
#       - tor-net
# EOL
#     fi

#     if [ "$DEPLOY_ONION_SITE" = true ]; then
#         cat >>"$DOCKER_YAML_PATH" <<EOL
  
# volumes:
#   tor-data:
#   tor-logs:

# EOL
#     fi
#     #-------------------------

# networks ----------------------
    cat >>"$DOCKER_YAML_PATH" <<EOL
networks:
EOL

    if [ "$DEPLOY_GHOST" = true ]; then
        cat >>"$DOCKER_YAML_PATH" <<EOL
    ghostnet-${domain_number}:
      name: "reverse-proxy_ghostnet-${domain_number}"
      external: true
    ghostdbnet-${domain_number}:
EOL
    fi

#     if [ "$DEPLOY_NEXTCLOUD" = true ]; then
#         cat >>"$DOCKER_YAML_PATH" <<EOL
#   nextclouddb-net:
#   nextcloud-net:
# EOL
#     fi

#     if [ "$DEPLOY_GITEA" = true ]; then
#         cat >>"$DOCKER_YAML_PATH" <<EOL
#   gitea-net:
#   giteadb-net:
# EOL
#     fi

#     if [ "$DEPLOY_ONION_SITE" = true ]; then
#         cat >>"$DOCKER_YAML_PATH" <<EOL
#   tor-net:
#   torghost-net:
# EOL
#     fi
#     # -------------------------------


#     if [ "$DEPLOY_ONION_SITE" = true ]; then
#         cat >>"$DOCKER_YAML_PATH" <<EOL
#   tor-config:
#     file: $(pwd)/tor/torrc
# EOL
#     fi
#     # -----------------------------


    docker stack deploy -c "$DOCKER_YAML_PATH" "$STACK_TAG"

    domain_number=$((domain_number+1))
done
