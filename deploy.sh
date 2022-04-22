#!/bin/bash

set -exu
cd "$(dirname "$0")"


check_dependencies () {
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "This script requires \"${cmd}\" to be installed. Please run 'sudo ~/sovereign-stack/install.sh'"
      exit 1
    fi
  done
}

# Check system's dependencies
check_dependencies wait-for-it dig rsync sshfs lxc docker-machine
# TODO remove dependency on Docker-machine. That's what we use to provision VM on 3rd party vendors. Looking for LXD endpoint.


MIGRATE_VPS=false
DOMAIN_NAME=
VPS_HOSTING_TARGET=lxd
RUN_CERT_RENEWAL=true
USER_NO_BACKUP=false
USER_RUN_RESTORE=false
BTC_CHAIN=testnet
UPDATE_BTCPAY=false
RECONFIGURE_BTCPAY_SERVER=false
BTCPAY_ADDITIONAL_HOSTNAMES=
LXD_DISK_TO_USE=
DEPLOY_BTCPAY_SERVER=false
REDEPLOY_STACK=false
MACVLAN_INTERFACE=


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
        --migrate)
            MIGRATE_VPS=true
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
export RUN_CERT_RENEWAL="$RUN_CERT_RENEWAL"

export BTC_CHAIN="$BTC_CHAIN"
export UPDATE_BTCPAY="$UPDATE_BTCPAY"
export MIGRATE_VPS="$MIGRATE_VPS"
export RECONFIGURE_BTCPAY_SERVER="$RECONFIGURE_BTCPAY_SERVER"
export MACVLAN_INTERFACE="$MACVLAN_INTERFACE"

# # first of all, if there are uncommited changes, we quit. You better stash your work yo!
# if git update-index --refresh| grep -q "needs update"; then
#     echo "ERROR: You have uncommited changes! Better stash your work with 'git stash'."
#     exit 1
# fi

# shellcheck disable=SC1091
source ./defaults.sh

# if there's a ./env file here, let's execute it. Admins can put various deployment-specific things there.
if [ -f $(pwd)/env ]; then
    source $(pwd)/env;
else
    touch "$(pwd)/env"
    echo "We stubbed out a '$(pwd)/env' file for you. Put any LXD-remote specific information in there."
    exit 1
fi

# iterate over all our server endpoints and provision them if needed.
# www
VPS_HOSTNAME=
for APP_TO_DEPLOY in btcpay www umbrel; do
    FQDN=
    export APP_TO_DEPLOY="$APP_TO_DEPLOY"
    # shellcheck disable=SC1091
    source ./shared.sh

    # skip this iteration if the site_definition says not to deploy btcpay server.
    if [ "$APP_TO_DEPLOY" = btcpay ]; then
        VPS_HOSTNAME="$BTCPAY_HOSTNAME"
        MAC_ADDRESS_TO_PROVISION="$BTCPAY_MAC_ADDRESS"
        if [ "$DEPLOY_BTCPAY_SERVER" = false ]; then
            continue
        fi
    fi

    # skip if the server config is set to not deploy.
    if [ "$APP_TO_DEPLOY" = www ]; then
        VPS_HOSTNAME="$WWW_HOSTNAME"
        MAC_ADDRESS_TO_PROVISION="$WWW_MAC_ADDRESS"
        if [ "$DEPLOY_WWW_SERVER" = false ]; then
            continue
        fi
    fi

    # skip umbrel if 
    if [ "$APP_TO_DEPLOY" = umbrel ]; then
        VPS_HOSTNAME="$UMBREL_HOSTNAME"
        MAC_ADDRESS_TO_PROVISION="$UMBREL_MAC_ADDRESS"
        if [ "$DEPLOY_UMBREL_VPS" = false ]; then
            continue
        fi
    fi

    export MAC_ADDRESS_TO_PROVISION="$MAC_ADDRESS_TO_PROVISION"
    export VPS_HOSTNAME="$VPS_HOSTNAME"
    export FQDN="$VPS_HOSTNAME.$DOMAIN_NAME"

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
        if [ "$MIGRATE_VPS" = true ]; then


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
                USER_RUN_RESTORE=true
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
        if [ "$MIGRATE_VPS" = true ]; then
            echo "INFO: User has indicated to delete the machine, but it doesn't exist. Going to create it anyway."
        fi

        # The machine does not exist. Let's bring it into existence, restoring from latest backup.
        echo "Machine does not exist. RUN_RESTORE=$USER_RUN_RESTORE RUN_BACKUP=false" 
        RUN_RESTORE="$USER_RUN_RESTORE" RUN_BACKUP=false RUN_SERVICES=true ./domain_init.sh
    fi
done
