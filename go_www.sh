#!/bin/bash

set -exu

TOR_CONFIG_PATH=

ssh "$FQDN" mkdir -p "$REMOTE_HOME/ghost_site" "$REMOTE_HOME/ghost_db"

if [ "$DEPLOY_NEXTCLOUD" = true ]; then
    ssh "$FQDN" "mkdir -p $REMOTE_NEXTCLOUD_PATH/db/data"
    ssh "$FQDN" "mkdir -p $REMOTE_NEXTCLOUD_PATH/db/logs"
    ssh "$FQDN" "mkdir -p $REMOTE_NEXTCLOUD_PATH/html"
fi

if [ "$DEPLOY_GITEA" = true ]; then
    ssh "$FQDN" "mkdir -p $REMOTE_GITEA_PATH/data $REMOTE_GITEA_PATH/db"
fi

# enable docker swarm mode so we can support docker stacks.
if ! docker info | grep -q "Swarm: active"; then
    docker swarm init
fi

# stop services.
if docker stack list --format "{{.Name}}" | grep -q webstack; then
    docker stack rm webstack
    sleep 20
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
        ssh "$FQDN" "sudo tar -xvf $REMOTE_HOME/certs.tar.gz -C /etc"
    else
        echo "ERROR: Certificates do not exist locally."
        exit 1
    fi
fi


if [ "$RUN_BACKUP"  = true ]; then
    ./backup_www.sh
fi

if [ "$RUN_RESTORE" = true ]; then
    ./restore_www.sh
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
    wait-for-it -t 320 "$FQDN:80"
    wait-for-it -t 320 "$FQDN:443"

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
