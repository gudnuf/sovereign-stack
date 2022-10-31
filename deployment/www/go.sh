#!/bin/bash

set -eu
cd "$(dirname "$0")"

# Create the nginx config file which covers all domains.
bash -c ./stub/nginx_config.sh

# redirect all docker commands to the remote host.
export DOCKER_HOST="ssh://ubuntu@$PRIMARY_WWW_FQDN"

for DOMAIN_NAME in ${DOMAIN_LIST//,/ }; do
    export DOMAIN_NAME="$DOMAIN_NAME"
    export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"

    # source the site path so we know what features it has.
    source ../../reset_env.sh
    source "$SITE_PATH/site_definition"
    source ../../domain_env.sh


    ### Let's check to ensure all the requiredsettings are set.
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

    if [ "$DEPLOY_NOSTR_RELAY" = true ]; then
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

    TOR_CONFIG_PATH=

done

./stop_docker_stacks.sh

if [ "$DEPLOY_ONION_SITE" = true ]; then
    # ensure the tor image is built
    docker build -t tor:latest ./tor

    # if the tor folder doesn't exist, we provision a new one. Otherwise you need to restore.
    # this is how we generate a new torv3 endpoint.
    if ! ssh "$PRIMARY_WWW_FQDN" "[ -d $REMOTE_HOME/tor/www ]"; then
        ssh "$PRIMARY_WWW_FQDN" "mkdir -p $REMOTE_HOME/tor"
        TOR_CONFIG_PATH="$(pwd)/tor/torrc-init"
        export TOR_CONFIG_PATH="$TOR_CONFIG_PATH"
        docker stack deploy -c ./tor.yml torstack
        sleep 20
        docker stack rm torstack
        sleep 20
    fi

    ONION_ADDRESS="$(ssh "$PRIMARY_WWW_FQDN" sudo cat "${REMOTE_HOME}"/tor/www/hostname)"
    export ONION_ADDRESS="$ONION_ADDRESS"

    # # Since we run a separate ghost process, we create a new directory and symlink it to the original
    # if ! ssh "$PRIMARY_WWW_FQDN" "[ -L $REMOTE_HOME/tor_ghost ]"; then
    #     ssh "$PRIMARY_WWW_FQDN" ln -s "$REMOTE_HOME/ghost_site/themes $REMOTE_HOME/tor_ghost/themes"
    # fi
fi

# nginx gets deployed first since it "owns" the docker networks of downstream services.
./stub/nginx_yml.sh

# next run our application stub logic. These deploy the apps too if configured to do so.
./stub/ghost_yml.sh
./stub/nextcloud_yml.sh
./stub/gitea_yml.sh


# # start a browser session; point it to port 80 to ensure HTTPS redirect.
# # WWW_FQDN is in our certificate, so we resolve to that.
# wait-for-it -t 320 "$WWW_FQDN:80"
# wait-for-it -t 320 "$WWW_FQDN:443"

# # open bowser tabs.
# if [ "$DEPLOY_GHOST" = true ]; then
#     xdg-open "http://$WWW_FQDN" > /dev/null 2>&1
# fi

# if [ "$DEPLOY_NEXTCLOUD" = true ]; then
#     xdg-open "http://$NEXTCLOUD_FQDN" > /dev/null 2>&1
# fi

# if [ "$DEPLOY_GITEA" = true ]; then
#     xdg-open "http://$GITEA_FQDN" > /dev/null 2>&1
# fi

# if [ "$DEPLOY_BTCPAY_SERVER" = true ]; then
#     xdg-open "http://$BTCPAY_USER_FQDN" > /dev/null 2>&1
# fi
