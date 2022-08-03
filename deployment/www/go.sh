#!/bin/bash

set -exu
cd "$(dirname "$0")"

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
    sleep 15
fi

# this will generate letsencrypt certs and pull them down locally.
# if [ "$VPS_HOSTING_TARGET" != lxd ]; then


# really we should change this if clause to some thing like
# "if the perimeter firewall allows port 80/443, then go ahead."
if [ "$RUN_CERT_RENEWAL" = true ]; then
    ./generate_certs.sh
fi

if [ "$RUN_BACKUP"  = true ]; then
    ./backup.sh
fi

if [ "$RUN_RESTORE" = true ]; then
    ./restore.sh
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
    mkdir -p "$SITE_PATH/stacks"
    DOCKER_YAML_PATH="$SITE_PATH/stacks/www.yml"
    export DOCKER_YAML_PATH="$DOCKER_YAML_PATH"
    bash -c ./stub_docker_yml.sh

    docker stack deploy -c "$DOCKER_YAML_PATH" webstack

    # start a browser session; point it to port 80 to ensure HTTPS redirect.
    wait-for-it -t 320 "$FQDN:80"
    wait-for-it -t 320 "$FQDN:443"

    # open bowser tabs.
    if [ "$DEPLOY_GHOST" = true ]; then
        xdg-open "http://$FQDN" > /dev/null 2>&1
    fi

    if [ "$DEPLOY_NEXTCLOUD" = true ]; then
        xdg-open "http://$NEXTCLOUD_FQDN" > /dev/null 2>&1
    fi

    if [ "$DEPLOY_GITEA" = true ]; then
        xdg-open "http://$GITEA_FQDN" > /dev/null 2>&1
    fi
fi
