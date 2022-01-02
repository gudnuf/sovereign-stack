#!/bin/bash

set -exuo nounset
cd "$(dirname "$0")"

TOR_CONFIG_PATH=

ssh "$FQDN" mkdir -p "$REMOTE_HOME/ghost_site" "$REMOTE_HOME/ghost_db"

if [ "$DEPLOY_NEXTCLOUD" = true ]; then
    ssh "$FQDN" mkdir -p "$REMOTE_NEXTCLOUD_PATH/db/data" \
    ssh "$FQDN" mkdir -p "$REMOTE_NEXTCLOUD_PATH/db/logs" \
    ssh "$FQDN" mkdir -p "$REMOTE_NEXTCLOUD_PATH/html"
fi

if [ "$DEPLOY_GITEA" = true ]; then
    ssh "$FQDN" mkdir -p "$REMOTE_GITEA_PATH/data" "$REMOTE_GITEA_PATH/db"
fi

# enable docker swarm mode so we can support docker stacks.
if ! docker info | grep -q "Swarm: active"; then
    docker swarm init
fi

# stop services.
if docker stack list --format "{{.Name}}" | grep -q webstack; then
    docker stack rm webstack
    sleep 10
fi

# this will generate letsencrypt certs and pull them down locally.
if [ "$VPS_HOSTING_TARGET" != lxd ]; then
    # really we should change this if clause to some thing like
    # "if the perimeter firewall allows port 80/443, then go ahead."
    if [ "$VPS_HOSTING_TARGET" = aws ] && [ "$RUN_CERT_RENEWAL" = true ]; then
        ./generate_certs.sh
    fi
else
    
    # restore the certs. If they don't exist in a backup we restore from SITE_PATH
    if [ -f "$SITE_PATH/certs.tar.gz" ]; then
        scp "$SITE_PATH/certs.tar.gz" "ubuntu@$FQDN:$REMOTE_HOME/certs.tar.gz"
        ssh "$FQDN" sudo tar -xvf "$REMOTE_HOME/certs.tar.gz" -C /etc
    else
        echo "ERROR: Certificates do not exist locally. You need to obtain some, perhaps by running with '--app=certonly'."
        exit 1
    fi
fi


if [ "$RUN_BACKUP"  = true ]; then
    ./backup_www.sh
fi

if [ "$RUN_RESTORE" = true ]; then
    ./restore_www.sh
fi

NEW_MATRIX_DEPLOYMENT=false
if [ "$DEPLOY_MATRIX" = true ]; then
    if ! ssh "$FQDN" "[ -d $REMOTE_HOME/matrix ]"; then
        NEW_MATRIX_DEPLOYMENT=true
        ssh "$FQDN" "mkdir $REMOTE_HOME/matrix && mkdir $REMOTE_HOME/matrix/db && mkdir $REMOTE_HOME/matrix/data"

        docker run -it --rm -v "$REMOTE_HOME/matrix/data":/data \
            -e SYNAPSE_SERVER_NAME="${DOMAIN_NAME}" \
            -e SYNAPSE_REGISTRATION_SHARED_SECRET="${MATRIX_SHARED_SECRET}" \
            -e SYNAPSE_REPORT_STATS=yes \
            -e POSTGRES_PASSWORD="${MATRIX_DB_PASSWORD}" \
            -e SYNAPSE_NO_TLS=1 \
            -e SYNAPSE_ENABLE_REGISTRATION=yes \
            -e SYNAPSE_LOG_LEVEL=DEBUG \
            -e POSTGRES_DB=synapse \
            -e POSTGRES_HOST=matrix-db \
            -e POSTGRES_USER=synapse \
            -e POSTGRES_PASSWORD="${MATRIX_DB_PASSWORD}" \
            "$MATRIX_IMAGE" generate
    fi
fi

if [ "$DEPLOY_ONION_SITE" = true ]; then
    # ensure the tor image is built
    docker build -t tor:latest ./tor

    # if the tor folder doesn't exist, we provision a new one. Otherwise you need to restore.
    # this is how we generate a new torv3 endpoint.
    if ! ssh "$FQDN" "[ -d $REMOTE_HOME/tor/www ]"; then
        ssh "$FQDN" "mkdir -p $REMOTE_HOME/tor"
        TOR_CONFIG_PATH="$(pwd)/tor/torrc-init"
        export TOR_CONFIG_PATH="$TOR_CONFIG_PATH"
        docker stack deploy -c ./tor.yml torstack
        sleep 20
        docker stack rm torstack
        sleep 20
    fi

    ONION_ADDRESS="$(ssh "$FQDN" sudo cat "${REMOTE_HOME}"/tor/www/hostname)"
    export ONION_ADDRESS="$ONION_ADDRESS"

    # # Since we run a separate ghost process, we create a new directory and symlink it to the original
    # if ! ssh "$FQDN" "[ -L $REMOTE_HOME/tor_ghost ]"; then
    #     ssh "$FQDN" ln -s "$REMOTE_HOME/ghost_site/themes $REMOTE_HOME/tor_ghost/themes"
    # fi
fi

if [ "$RUN_SERVICES" = true ]; then
    docker stack deploy -c "$DOCKER_YAML_PATH" webstack

    # start a browser session; point it to port 80 to ensure HTTPS redirect.
    wait-for-it -t 320 "$DOMAIN_NAME:80"
    wait-for-it -t 320 "$DOMAIN_NAME:443"

    if [ "$DEPLOY_MATRIX" = true ]; then
        # If this is a new Matrix deployment, then we should add the default admin user.
        if [ $NEW_MATRIX_DEPLOYMENT = true ]; then
            # get the container ID for matrix/synapse.
            MATRIX_CONTAINER_ID="$(docker ps | grep matrixdotorg | awk '{print $1;}')"

            # create the user.
            docker exec -it "$MATRIX_CONTAINER_ID" register_new_matrix_user http://localhost:8008 -u "$ADMIN_ACCOUNT_USERNAME" -p "$MATRIX_ADMIN_PASSWORD" -a --config /data/homeserver.yaml
        fi
    fi

    # open bowser tabs.
    if [ "$DEPLOY_GHOST" = true ]; then
        xdg-open "http://$FQDN"
    fi

    if [ "$DEPLOY_NEXTCLOUD" = true ]; then
        xdg-open "http://$NEXTCLOUD_FQDN"
    fi

    if [ "$DEPLOY_GITEA" = true ]; then
        xdg-open "http://$GITEA_FQDN"
    fi
fi
