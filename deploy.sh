#!/bin/bash

set -exuo nounset
cd "$(dirname "$0")"

USER_DELETE_MACHINE=false
DOMAIN_NAME=
VPS_HOSTING_TARGET=lxd
RUN_CERT_RENEWAL=true
USER_NO_BACKUP=false
USER_RUN_RESTORE=false
BTC_CHAIN=testnet
UPDATE_BTCPAY=false
MIGRATE_BTCPAY_SERVER=false
RECONFIGURE_BTCPAY_SERVER=false
BTCPAY_ADDITIONAL_HOSTNAMES=
LXD_DISK_TO_USE=
DEV_BTCPAY_MAC_ADDRESS=

for i in "$@"; do
    case $i in
        --domain=*)
            DOMAIN_NAME="${i#*=}"
            shift
        ;;
        --hosting-provider=*)
            VPS_HOSTING_TARGET="${i#*=}"
            shift
        ;;
        --restore)
            USER_RUN_RESTORE=true
            shift
        ;;
        --update-btcpay)
            UPDATE_BTCPAY=true
            shift
        ;;
        --no-backup)
            USER_NO_BACKUP=true
            shift
        ;;
        --delete)
            USER_DELETE_MACHINE=true
            shift
        ;;
        --storage-backend=*)
            LXD_DISK_TO_USE="${i#*=}"
            shift
        ;;
        --no-cert-renew)
            RUN_CERT_RENEWAL=false
            shift
        ;;
        --mainnet)
            BTC_CHAIN=mainnet
            shift
        ;;
        --migrate)
            MIGRATE_BTCPAY_SERVER=true
            shift
        ;;
        --reconfigure-btcpay)
            RECONFIGURE_BTCPAY_SERVER=true
            shift
        ;;
        *)
            # unknown option
        ;;
    esac
done

export DOMAIN_NAME="$DOMAIN_NAME"
export VPS_HOSTING_TARGET="$VPS_HOSTING_TARGET"
export LXD_DISK_TO_USE="$LXD_DISK_TO_USE"
export DEV_BTCPAY_MAC_ADDRESS="$DEV_BTCPAY_MAC_ADDRESS"
export RUN_CERT_RENEWAL="$RUN_CERT_RENEWAL"

export BTC_CHAIN="$BTC_CHAIN"
export UPDATE_BTCPAY="$UPDATE_BTCPAY"
export MIGRATE_BTCPAY_SERVER="$MIGRATE_BTCPAY_SERVER"
export RECONFIGURE_BTCPAY_SERVER="$RECONFIGURE_BTCPAY_SERVER"

# # first of all, if there are uncommited changes, we quit. You better stash your work yo!
# if git update-index --refresh| grep -q "needs update"; then
#     echo "ERROR: You have uncommited changes! Better stash your work with 'git stash'."
#     exit 1
# fi

# shellcheck disable=SC1091
source ./defaults.sh

# iterate over all our server endpoints and provision them if needed.
# www
for APP_TO_DEPLOY in btcpay www; do
    FQDN=
    export APP_TO_DEPLOY="$APP_TO_DEPLOY"
    # shellcheck disable=SC1091
    source ./shared.sh

    # skip this iteration if the site_definition says not to deploy btcpay server.
    if [ "$APP_TO_DEPLOY" = btcpay ]; then
        FQDN="$BTCPAY_HOSTNAME.$DOMAIN_NAME"
        if [ "$DEPLOY_BTCPAY_SERVER" = false ]; then
            continue
        fi
    fi

    # skip if the server config is set to not deploy.
    if [ "$APP_TO_DEPLOY" = www ]; then
        FQDN="$WWW_HOSTNAME.$DOMAIN_NAME"
        if [ "$DEPLOY_WWW_SERVER" = false ]; then
            continue
        fi
    fi

    export FQDN="$FQDN"

    # generate the docker yaml and nginx configs.
    ./stub_docker_yml.sh
    ./stub_nginxconf.sh

    MACHINE_EXISTS=false
    if [ "$VPS_HOSTING_TARGET" = aws ] && docker-machine ls -q | grep -q "$FQDN"; then
        MACHINE_EXISTS=true
    fi

    if [ "$VPS_HOSTING_TARGET" = lxd ] && lxc list --format csv | grep -q "$FQDN"; then
        MACHINE_EXISTS=true
    fi

    if [ "$USER_NO_BACKUP" = true ]; then
        RUN_BACKUP=true
    fi

    if [ "$MACHINE_EXISTS"  = true ]; then
        # we delete the machine if the user has directed us to
        if [ "$USER_DELETE_MACHINE" = true ]; then
            # run the domain_init based on user input.
            if [ "$USER_NO_BACKUP"  = true ]; then
                echo "Machine exists. We don't need to back it up because the user has directed --no-backup."
            else
                echo "Machine exists.  Since we're going to delete it, let's grab a backup. We don't need to restore services since we're deleting it."
                RUN_RESTORE=false RUN_BACKUP=true RUN_SERVICES=false ./domain_init.sh
            fi

            # delete the remote VPS.
            if [ "$VPS_HOSTING_TARGET" = aws ]; then
                if [ "$APP_TO_DEPLOY" != btcpay ]; then
                   # docker-machine rm -f "$FQDN"
                   echo "ERROR: NOT IMPLEMENTED"
                fi
            elif [ "$VPS_HOSTING_TARGET" = lxd ]; then
                lxc delete --force "$LXD_VM_NAME"
            fi

            # Then we run the script again to re-instantiate a new VPS, restoring all user data 
            # if restore directory doesn't exist, then we end up with a new site.
            echo "INFO: Recreating the remote VPS then restoring user data."
            RUN_RESTORE="$USER_RUN_RESTORE" RUN_BACKUP=false RUN_SERVICES=true ./domain_init.sh
        else
            if [ "$USER_NO_BACKUP"  = true ]; then
                RUN_BACKUP=false
                echo "INFO: Maintaining existing VPS. RUN_BACKUP=$RUN_BACKUP RUN_RESTORE=$USER_RUN_RESTORE"
            else
                RUN_BACKUP=true
                echo "INFO: Maintaining existing VPS. RUN_BACKUP=$RUN_BACKUP RUN_RESTORE=$USER_RUN_RESTORE"
            fi

            RUN_RESTORE="$USER_RUN_RESTORE" RUN_BACKUP="$RUN_BACKUP" RUN_SERVICES=true ./domain_init.sh
        fi
    else
        if [ "$USER_DELETE_MACHINE" = true ]; then
            echo "INFO: User has indicated to delete the machine, but it doesn't exist. Going to create it anyway."
        fi

        # The machine does not exist. Let's bring it into existence, restoring from latest backup.
        echo "Machine does not exist. RUN_RESTORE=$USER_RUN_RESTORE RUN_BACKUP=false" 
        RUN_RESTORE="$USER_RUN_RESTORE" RUN_BACKUP=false RUN_SERVICES=true ./domain_init.sh
    fi
done
