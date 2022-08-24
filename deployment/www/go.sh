#!/bin/bash

set -exuo
cd "$(dirname "$0")"

if [ "$DEPLOY_GHOST" = true ]; then
    if [ -z "$GHOST_MYSQL_PASSWORD" ]; then
        echo "ERROR: Ensure GHOST_MYSQL_PASSWORD is configured in your site_definition."
        exit 1
    fi

    if [ -z "$GHOST_MYSQL_ROOT_PASSWORD" ]; then
        echo "ERROR: Ensure GHOST_MYSQL_ROOT_PASSWORD is configured in your site_definition."
        exit 1
    fi
fi

if [ "$DEPLOY_GITEA" = true ]; then
    if [ -z "$GITEA_MYSQL_PASSWORD" ]; then
        echo "ERROR: Ensure GITEA_MYSQL_PASSWORD is configured in your site_definition."
        exit 1
    fi
    if [ -z "$GITEA_MYSQL_ROOT_PASSWORD" ]; then
        echo "ERROR: Ensure GITEA_MYSQL_ROOT_PASSWORD is configured in your site_definition."
        exit 1
    fi
fi

if [ "$DEPLOY_NEXTCLOUD" = true ]; then
    if [ -z "$NEXTCLOUD_MYSQL_ROOT_PASSWORD" ]; then
        echo "ERROR: Ensure NEXTCLOUD_MYSQL_ROOT_PASSWORD is configured in your site_definition."
        exit 1
    fi

    if [ -z "$NEXTCLOUD_MYSQL_PASSWORD" ]; then
        echo "ERROR: Ensure NEXTCLOUD_MYSQL_PASSWORD is configured in your site_definition."
        exit 1
    fi
fi

if [ "$DEPLOY_NOSTR" = true ]; then
    if [ -z "$NOSTR_ACCOUNT_PUBKEY" ]; then
        echo "ERROR: Ensure NOSTR_ACCOUNT_PUBKEY is configured in your site_definition."
        exit 1
    fi

    if [ -z "$NOSTR_ACCOUNT_PUBKEY" ]; then
        echo "ERROR: Ensure NOSTR_ACCOUNT_PUBKEY is configured in your site_definition."
        exit 1
    fi    
fi

if [ -z "$DUPLICITY_BACKUP_PASSPHRASE" ]; then
    echo "ERROR: Ensure DUPLICITY_BACKUP_PASSPHRASE is configured in your site_definition."
    exit 1
fi

if [ -z "$DOMAIN_NAME" ]; then
    echo "ERROR: Ensure DOMAIN_NAME is configured in your site_definition."
    exit 1
fi

if [ -z "$NOSTR_ACCOUNT_PUBKEY" ]; then 
    echo "ERROR: You MUST specify a Nostr public key. This is how you get all your social features."
    echo "INFO: Go to your site_definition file and set the NOSTR_ACCOUNT_PUBKEY variable."
    exit 1
fi

bash -c ./stub_nginxconf.sh

TOR_CONFIG_PATH=

ssh "$WWW_FQDN" mkdir -p "$REMOTE_HOME/ghost_site" "$REMOTE_HOME/ghost_db"

if [ "$DEPLOY_NEXTCLOUD" = true ]; then
    ssh "$WWW_FQDN" "mkdir -p $REMOTE_NEXTCLOUD_PATH/db/data"
    ssh "$WWW_FQDN" "mkdir -p $REMOTE_NEXTCLOUD_PATH/db/logs"
    ssh "$WWW_FQDN" "mkdir -p $REMOTE_NEXTCLOUD_PATH/html"
fi

if [ "$DEPLOY_GITEA" = true ]; then
    ssh "$FQDN" "mkdir -p $REMOTE_GITEA_PATH/data $REMOTE_GITEA_PATH/db"
fi

# stop services.
if docker stack list --format "{{.Name}}" | grep -q webstack; then
    docker stack rm webstack
    sleep 15
fi


if [ "$BACKUP_WWW"  = true ]; then
    ./backup.sh
fi

if [ "$RESTORE_WWW" = true ]; then
    # Generally speaking we try to restore data. But if the BACKUP directory was
    # just created, we know that we'll deploy fresh.
    ./restore.sh
else
    ./generate_certs.sh
fi


if [ "$DEPLOY_ONION_SITE" = true ]; then
    # ensure the tor image is built
    docker build -t tor:latest ./tor

    # if the tor folder doesn't exist, we provision a new one. Otherwise you need to restore.
    # this is how we generate a new torv3 endpoint.
    if ! ssh "$WWW_FQDN" "[ -d $REMOTE_HOME/tor/www ]"; then
        ssh "$WWW_FQDN" "mkdir -p $REMOTE_HOME/tor"
        TOR_CONFIG_PATH="$(pwd)/tor/torrc-init"
        export TOR_CONFIG_PATH="$TOR_CONFIG_PATH"
        docker stack deploy -c ./tor.yml torstack
        sleep 20
        docker stack rm torstack
        sleep 20
    fi

    ONION_ADDRESS="$(ssh "$WWW_FQDN" sudo cat "${REMOTE_HOME}"/tor/www/hostname)"
    export ONION_ADDRESS="$ONION_ADDRESS"

    # # Since we run a separate ghost process, we create a new directory and symlink it to the original
    # if ! ssh "$WWW_FQDN" "[ -L $REMOTE_HOME/tor_ghost ]"; then
    #     ssh "$WWW_FQDN" ln -s "$REMOTE_HOME/ghost_site/themes $REMOTE_HOME/tor_ghost/themes"
    # fi
fi

#if [ "$RUN_SERVICES" = true ]; then
mkdir -p "$SITE_PATH/stacks"
DOCKER_YAML_PATH="$SITE_PATH/stacks/www.yml"
export DOCKER_YAML_PATH="$DOCKER_YAML_PATH"
bash -c ./stub_docker_yml.sh

docker stack deploy -c "$DOCKER_YAML_PATH" webstack

# start a browser session; point it to port 80 to ensure HTTPS redirect.
wait-for-it -t 320 "$WWW_FQDN:80"
wait-for-it -t 320 "$WWW_FQDN:443"

# open bowser tabs.
if [ "$DEPLOY_GHOST" = true ]; then
    xdg-open "http://$WWW_FQDN" > /dev/null 2>&1
fi

if [ "$DEPLOY_NEXTCLOUD" = true ]; then
    xdg-open "http://$NEXTCLOUD_FQDN" > /dev/null 2>&1
fi

if [ "$DEPLOY_GITEA" = true ]; then
    xdg-open "http://$GITEA_FQDN" > /dev/null 2>&1
fi
#fi
