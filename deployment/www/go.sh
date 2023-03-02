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
    source ../../defaults.sh
    source "$SITE_PATH/site_definition"
    source ../domain_env.sh

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

    if [ -z "$DUPLICITY_BACKUP_PASSPHRASE" ]; then
        echo "ERROR: Ensure DUPLICITY_BACKUP_PASSPHRASE is configured in your site_definition."
        exit 1
    fi

    if [ -z "$DOMAIN_NAME" ]; then
        echo "ERROR: Ensure DOMAIN_NAME is configured in your site_definition."
        exit 1
    fi

done

./stop_docker_stacks.sh


# TODO check if there are any other stacks that are left running (other than reverse proxy)
# if so, this may mean the user has disabled one or more domains and that existing sites/services
# are still running. We should prompt the user of this and quit. They have to go manually docker stack remove these.
if [[ $(docker stack ls | wc -l) -gt 2 ]]; then
    echo "WARNING! You still have stacks running. If you have modified the SITES list, you may need to go remove the docker stacks runnong the remote machine."
    echo "exiting."
    exit 1
fi



# ok, the backend stacks are stopped.
if [ "$RESTART_FRONT_END" = true ]; then
    # remove the nginx stack
    if docker stack list --format "{{.Name}}" | grep -q reverse-proxy; then
        sleep 2

        docker stack rm reverse-proxy

        # wait for all docker containers to stop.
        # TODO see if there's a way to check for this.
        sleep 20
    fi

    # generate the certs and grab a backup
    if [ "$RUN_CERT_RENEWAL" = true ]; then
        ./generate_certs.sh
    fi

    # let's backup all our letsencrypt certs
    export APP="letsencrypt"
    for DOMAIN_NAME in ${DOMAIN_LIST//,/ }; do
        export DOMAIN_NAME="$DOMAIN_NAME"
        export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"

        # source the site path so we know what features it has.
        source ../../defaults.sh
        source "$SITE_PATH/site_definition"
        source ../domain_env.sh

        # these variable are used by both backup/restore scripts.
        export REMOTE_BACKUP_PATH="$REMOTE_HOME/backups/www/$APP/$DOMAIN_IDENTIFIER"
        export REMOTE_SOURCE_BACKUP_PATH="$REMOTE_HOME/$APP/$DOMAIN_NAME"

        # ensure our local backup path exists so we can pull down the duplicity archive to the management machine.
        export LOCAL_BACKUP_PATH="$SITE_PATH/backups/www/$APP"
        mkdir -p "$LOCAL_BACKUP_PATH"

        if [ "$RESTORE_WWW" = true ]; then
            sleep 5
            echo "STARTING restore_path.sh for letsencrypt."
            ./restore_path.sh
            #ssh "$PRIMARY_WWW_FQDN" sudo chown ubuntu:ubuntu "$REMOTE_HOME/$APP"
        elif [ "$BACKUP_APPS"  = true ]; then
            # if we're not restoring, then we may or may not back up.
            ./backup_path.sh
        fi
    done
fi

# nginx gets deployed first since it "owns" the docker networks of downstream services.
./stub/nginx_yml.sh

# next run our application stub logic. These deploy the apps too if configured to do so.
./stub/ghost_yml.sh
./stub/nextcloud_yml.sh
./stub/gitea_yml.sh
./stub/nostr_yml.sh
./deploy_clams.sh

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
