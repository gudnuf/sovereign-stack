#!/bin/bash

set -exu
cd "$(dirname "$0")"


if [ "$DEPLOY_ONION_SITE" = true ]; then
    if [ -z "$ONION_ADDRESS" ]; then
        echo "ERROR: ONION_ADDRESS is not defined."
        exit 1
    fi
fi


# here's the NGINX config. We support ghost and nextcloud.
echo "" > "$DOCKER_YAML_PATH"

cat >>"$DOCKER_YAML_PATH" <<EOL
version: "3.8"
services:

EOL


# This is the ghost for HTTPS (not over Tor)
cat >>"$DOCKER_YAML_PATH" <<EOL
  ghost:
    image: ${GHOST_IMAGE}
    networks:
      - ghost-net
      - ghostdb-net
    volumes:
      - ${REMOTE_HOME}/ghost_site:/var/lib/ghost/content
    environment:
      - url=https://${FQDN}
      - mail__from="${MAIL_FROM}"
      - mail__options__service=SMTP
      - mail__transport=SMTP
      - mail__options__host=${SMTP_SERVER}
      - mail__options__port=${SMTP_PORT}
      - mail__options__auth__user=${SMTP_LOGIN}
      - mail__options__auth__pass=\${SMTP_PASSWORD}
      - database__client=mysql
      - database__connection__host=ghostdb
      - database__connection__user=ghost
      - database__connection__password=\${GHOST_MYSQL_PASSWORD}
      - database__connection__database=ghost
      - database__pool__min=0
      - privacy__useStructuredData=true
    deploy:
      restart_policy:
        condition: on-failure

  ghostdb:
    image: ${GHOST_DB_IMAGE}
    networks:
      - ghostdb-net
    volumes:
      - ${REMOTE_HOME}/ghost_db:/var/lib/mysql
    environment:
       - MYSQL_ROOT_PASSWORD=\${GHOST_MYSQL_ROOT_PASSWORD}
       - MYSQL_DATABASE=ghost
       - MYSQL_USER=ghost
       - MYSQL_PASSWORD=\${GHOST_MYSQL_PASSWORD}
    deploy:
      restart_policy:
        condition: on-failure

EOL


if [ "$DEPLOY_NEXTCLOUD" = true ]; then
cat >>"$DOCKER_YAML_PATH" <<EOL
  nextcloud-db:
    image: ${NEXTCLOUD_DB_IMAGE}
    command: --transaction-isolation=READ-COMMITTED --binlog-format=ROW --innodb_read_only_compressed=OFF
    networks:
      - nextclouddb-net
    volumes:
      - ${REMOTE_HOME}/nextcloud/db/data:/var/lib/mysql
    environment:
      - MARIADB_ROOT_PASSWORD=\${NEXTCLOUD_MYSQL_ROOT_PASSWORD}
      - MYSQL_PASSWORD=\${NEXTCLOUD_MYSQL_PASSWORD}
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
    deploy:
      restart_policy:
        condition: on-failure

  nextcloud:
    image: ${NEXTCLOUD_IMAGE}
    networks:
      - nextclouddb-net
      - nextcloud-net
    volumes:
      - ${REMOTE_HOME}/nextcloud/html:/var/www/html
    environment:
      - MYSQL_PASSWORD=\${NEXTCLOUD_MYSQL_PASSWORD}
      - MYSQL_DATABASE=nextcloud
      - MYSQL_USER=nextcloud
      - MYSQL_HOST=nextcloud-db
      - NEXTCLOUD_TRUSTED_DOMAINS=${DOMAIN_NAME}
      - OVERWRITEHOST=${NEXTCLOUD_FQDN}
      - OVERWRITEPROTOCOL=https
      - SERVERNAME=${NEXTCLOUD_FQDN}
    deploy:
      restart_policy:
        condition: on-failure

EOL
fi



if [ "$DEPLOY_MATRIX" = true ]; then
cat >>"$DOCKER_YAML_PATH" <<EOL
  matrix:
    image: ${MATRIX_IMAGE}
    volumes:
      - ${REMOTE_HOME}/matrix/data:/data
    networks:
      - matrix-net
      - matrixdb-net
    deploy:
      restart_policy:
        condition: on-failure

  matrix-db:
    image: ${MATRIX_DB_IMAGE}
    volumes:
      - ${REMOTE_HOME}/matrix/db:/var/lib/postgresql/data
    networks:
      - matrixdb-net
    environment:
      - POSTGRES_PASSWORD=\${MATRIX_DB_PASSWORD}
      - POSTGRES_USER=synapse
    deploy:
      restart_policy:
        condition: on-failure

EOL
fi



if [ "$DEPLOY_GITEA" = true ]; then
cat >>"$DOCKER_YAML_PATH" <<EOL
  gitea:
    image: ${GITEA_IMAGE}
    volumes:
      - ${REMOTE_GITEA_PATH}/data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=mysql
      - GITEA__database__HOST=gitea-db:3306
      - GITEA__database__NAME=gitea
      - GITEA__database__USER=gitea
      - GITEA__PASSWD=${GITEA_MYSQL_PASSWORD}
    networks:
      - gitea-net
      - giteadb-net
    deploy:
      restart_policy:
        condition: on-failure

  gitea-db:
    image: ${GITEA_DB_IMAGE}
    networks:
      - giteadb-net
    volumes:
      - ${REMOTE_GITEA_PATH}/db:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=\${GITEA_MYSQL_ROOT_PASSWORD}
      - MYSQL_PASSWORD=\${GITEA_MYSQL_PASSWORD}
      - MYSQL_DATABASE=gitea
      - MYSQL_USER=gitea
    deploy:
      restart_policy:
        condition: on-failure
EOL
fi



if [ "$DEPLOY_ONION_SITE" = true ]; then
cat >>"$DOCKER_YAML_PATH" <<EOL
  # a hidden service that routes to the nginx container at http://onionurl.onion server block
  tor-onion:
    image: tor:latest
    networks:
      - tor-net
    volumes:
      - ${REMOTE_HOME}/tor:/var/lib/tor
      - tor-logs:/var/log/tor
    configs:
      - source: tor-config
        target: /etc/tor/torrc
        mode: 0644
    deploy:
      mode: replicated
      replicas: 1
      restart_policy:
        condition: on-failure

  tor-ghost:
    image: ${GHOST_IMAGE}
    networks:
      - ghostdb-net
      - ghost-net
    volumes:
      - ${REMOTE_HOME}/tor_ghost:/var/lib/ghost/content
    environment:
      - url=https://${ONION_ADDRESS}
      - mail__from=${MAIL_FROM}
      - mail__options__service=SMTP
      - mail__transport=SMTP
      - mail__options__host=${SMTP_SERVER}
      - mail__options__port=${SMTP_PORT}
      - mail__options__auth__user=${SMTP_LOGIN}
      - mail__options__auth__pass=\${SMTP_PASSWORD}
      - database__client=mysql
      - database__connection__host=ghostdb
      - database__connection__user=ghost
      - database__connection__password=\${GHOST_MYSQL_PASSWORD}
      - database__connection__database=ghost
    deploy:
      restart_policy:
        condition: on-failure

EOL
fi

# NGINX required
cat >>"$DOCKER_YAML_PATH" <<EOL
  nginx:
    image: ${NGINX_IMAGE}
    ports:
      - 0.0.0.0:443:443
      - 0.0.0.0:80:80
      - 0.0.0.0:8448:8448
    networks:
      - ghost-net
EOL

if [ "$DEPLOY_ONION_SITE" = true ]; then
cat >>"$DOCKER_YAML_PATH" <<EOL
      - torghost-net
EOL
fi

if [ "$DEPLOY_NEXTCLOUD" = true ]; then
cat >>"$DOCKER_YAML_PATH" <<EOL
      - nextcloud-net
EOL
fi

if [ "$DEPLOY_GITEA" = true ]; then
cat >>"$DOCKER_YAML_PATH" <<EOL
      - gitea-net
EOL
fi

if [ "$DEPLOY_MATRIX" = true ]; then
cat >>"$DOCKER_YAML_PATH" <<EOL
      - matrix-net
EOL
fi

if [ "$DEPLOY_ONION_SITE" = true ]; then
cat >>"$DOCKER_YAML_PATH" <<EOL
      - tor-net
EOL
fi

# the rest of the nginx config
cat >>"$DOCKER_YAML_PATH" <<EOL
    volumes:
      - /etc/letsencrypt:/etc/letsencrypt:ro
    configs:
      - source: nginx-config
        target: /etc/nginx/nginx.conf
    deploy:
      restart_policy:
        condition: on-failure
EOL

if [ "$DEPLOY_ONION_SITE" = true ]; then
cat >>"$DOCKER_YAML_PATH" <<EOL
  
volumes:
  tor-data:
  tor-logs:

EOL
fi
#-------------------------

# networks ----------------------
cat >>"$DOCKER_YAML_PATH" <<EOL
networks:
EOL

if [ "$DEPLOY_GHOST" = true ]; then
cat >>"$DOCKER_YAML_PATH" <<EOL
  ghost-net:
  ghostdb-net:
EOL
fi

if [ "$DEPLOY_NEXTCLOUD" = true ]; then
cat >>"$DOCKER_YAML_PATH" <<EOL
  nextclouddb-net:
  nextcloud-net:
EOL
fi

if [ "$DEPLOY_MATRIX" = true ]; then
cat >>"$DOCKER_YAML_PATH" <<EOL
  matrix-net:
  matrixdb-net:
EOL
fi

if [ "$DEPLOY_GITEA" = true ]; then
cat >>"$DOCKER_YAML_PATH" <<EOL
  gitea-net:
  giteadb-net:
EOL
fi

if [ "$DEPLOY_ONION_SITE" = true ]; then
cat >>"$DOCKER_YAML_PATH" <<EOL
  tor-net:
  torghost-net:
EOL
fi
# -------------------------------


# configs ----------------------
cat >>"$DOCKER_YAML_PATH" <<EOL

configs:
  nginx-config:
    file: ${SITE_PATH}/nginx.conf
EOL

if [ "$DEPLOY_ONION_SITE" = true ]; then
cat >>"$DOCKER_YAML_PATH" <<EOL
  tor-config:
    file: $(pwd)/tor/torrc
EOL
fi
# -----------------------------