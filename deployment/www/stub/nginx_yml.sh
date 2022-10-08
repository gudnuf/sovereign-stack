#!/bin/bash

set -euox
cd "$(dirname "$0")"

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

    for DOMAIN_NAME in ${DOMAIN_LIST//,/ }; do
        export DOMAIN_NAME="$DOMAIN_NAME"
        export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"

        # source the site path so we know what features it has.
        source ../../../reset_env.sh
        source "$SITE_PATH/site_definition"
        source ../../../domain_env.sh


        for LANGUAGE_CODE in ${SITE_LANGUAGE_CODES//,/ }; do
            # We create another ghost instance under /
            cat >> "$DOCKER_YAML_PATH" <<EOL
        - ghostnet-$DOCKER_STACK_SUFFIX-$LANGUAGE_CODE
EOL
        
            if [ "$LANGUAGE_CODE" = en ]; then
                if [ "$DEPLOY_GITEA" = "true" ]; then
                cat >> "$DOCKER_YAML_PATH" <<EOL
        - giteanet-$DOCKER_STACK_SUFFIX-en
EOL
                fi
            fi

        done

        

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



################ NETWORKS SECTION

    cat >> "$DOCKER_YAML_PATH" <<EOL
networks:
EOL


    for DOMAIN_NAME in ${DOMAIN_LIST//,/ }; do
        export DOMAIN_NAME="$DOMAIN_NAME"
        export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"

        # source the site path so we know what features it has.
        source ../../../reset_env.sh
        source "$SITE_PATH/site_definition"
        source ../../../domain_env.sh

        # for each language specified in the site_definition, we spawn a separate ghost container
        # at https://www.domain.com/$LANGUAGE_CODE
        for LANGUAGE_CODE in ${SITE_LANGUAGE_CODES//,/ }; do
            cat >> "$DOCKER_YAML_PATH" <<EOL
  ghostnet-$DOCKER_STACK_SUFFIX-$LANGUAGE_CODE:
    attachable: true

EOL

        done


        if [ "$DEPLOY_GITEA" = true ]; then
            cat >> "$DOCKER_YAML_PATH" <<EOL
  giteanet-$DOCKER_STACK_SUFFIX-en:
    attachable: true

EOL
        fi

    done

docker stack deploy -c "$DOCKER_YAML_PATH" "reverse-proxy"
# iterate over all our domains and create the nginx config file.
