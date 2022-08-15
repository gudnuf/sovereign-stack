#!/bin/bash

set -eux
cd "$(dirname "$0")"

check_dependencies () {
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "This script requires \"${cmd}\" to be installed. Please run 'install.sh'."
      exit 1
    fi
  done
}

# Check system's dependencies
check_dependencies wait-for-it dig rsync sshfs lxc docker-machine

# TODO remove dependency on Docker-machine. That's what we use to provision VM on 3rd party vendors. Looking for LXD endpoint.

# let's check to ensure the management machine is on the Baseline ubuntu 21.04
if ! lsb_release -d | grep -q "Ubuntu 22.04"; then
    echo "ERROR: Your machine is not running the Ubuntu 22.04 LTS baseline OS on your management machine."
    exit 1
fi

MIGRATE_VPS=false
DOMAIN_NAME=
RESTORE_ARCHIVE=
VPS_HOSTING_TARGET=lxd
RUN_CERT_RENEWAL=true
USER_NO_BACKUP=false
USER_RUN_RESTORE=false
RESTORE_WWW_USERDATA=true
RESTORE_BTCPAY=false
USER_SKIP_WWW=false
USER_SKIP_BTCPAY=false
UPDATE_BTCPAY=false
RECONFIGURE_BTCPAY_SERVER=false
DEPLOY_BTCPAY_SERVER=false
CLUSTER_NAME="$(lxc remote get-default)"
RUN_BACKUP=true

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --aws)
            VPS_HOSTING_TARGET=aws
            shift
        ;;
        --restore-www)
            USER_RUN_RESTORE=true
            RUN_CERT_RENEWAL=false
            USER_NO_BACKUP=true
            shift
        ;;
        --restore-btcpay)
            RESTORE_BTCPAY=true
            shift
        ;;
        --archive=*)
            RESTORE_ARCHIVE="${i#*=}"
            shift
        ;;
        --domain=*)
            DOMAIN_NAME="${i#*=}"
            shift
        ;;
        --update-btcpay)
            UPDATE_BTCPAY=true
            shift
        ;;
        --skip-www)
            USER_SKIP_WWW=true
            shift
        ;;
        --skip-btcpay)
            USER_SKIP_BTCPAY=true
            shift
        ;;
        --no-backup)
            USER_NO_BACKUP=true
            shift
        ;;
        --migrate)
            MIGRATE_VPS=true
            RUN_CERT_RENEWAL=false
            shift
        ;;
        --no-cert-renew)
            RUN_CERT_RENEWAL=false
            shift
        ;;
        --reconfigure-btcpay)
            RECONFIGURE_BTCPAY_SERVER=true
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

# set up our default paths.
source ./defaults.sh

export CACHES_DIR="$HOME/ss-cache"
export SSH_HOME="$HOME/.ssh"
export DOMAIN_NAME="$DOMAIN_NAME"
export REGISTRY_DOCKER_IMAGE="registry:2"
export RESTORE_ARCHIVE="$RESTORE_ARCHIVE"


if [ "$VPS_HOSTING_TARGET" = aws ]; then

    if [ -z "$DOMAIN_NAME" ]; then
        echo "ERROR: Please specify a domain name with --domain= when using --aws."
        exit 1
    fi

    CLUSTER_NAME="docker-machine"
fi

export CLUSTER_NAME="$CLUSTER_NAME"
export CLUSTER_PATH="$CLUSTERS_DIR/$CLUSTER_NAME"

# ensure our cluster path is created.
mkdir -p "$CLUSTER_PATH"

# if an authorized_keys file does not exist, we'll stub one out with the current user.
# add additional id_rsa.pub entries manually for more administrative logins.
if [ ! -f "$CLUSTER_PATH/authorized_keys" ]; then
    cat "$SSH_HOME/id_rsa.pub" >> "$CLUSTER_PATH/authorized_keys"
    echo "INFO: Sovereign Stack just stubbed out '$CLUSTER_PATH/authorized_keys'. Go update it."
    echo "      Add ssh pubkeys for your various management machines, if any. We've stubbed it out"
    echo "      with your ssh pubkey at '$HOME/.ssh/id_rsa.pub'."
    exit 1
fi

if [ "$VPS_HOSTING_TARGET" = lxd ]; then
    CLUSTER_DEFINITION="$CLUSTER_PATH/cluster_definition"
    export CLUSTER_DEFINITION="$CLUSTER_DEFINITION"

    #########################################
    if [ ! -f "$CLUSTER_DEFINITION" ]; then
        echo "ERROR: The cluster defintion could not be found. You may need to re-run 'ss-cluster create'."
        exit 1
    fi
        
    source "$CLUSTER_DEFINITION"

    ###########################3
    # # This section is done to the management machine. We deploy a registry pull through cache on port 5000
    # if ! docker volume list | grep -q registry_data; then
    #     docker volume create registry_data
    # fi

    # if the registry URL isn't defined, then we just use the upstream dockerhub.
    # recommended to run a registry cache on your management machine though.
    if [ -n "$REGISTRY_URL" ]; then

cat > "$CLUSTER_PATH/registry.yml" <<EOL
version: 0.1
http:
  addr: 0.0.0.0:5000
  host: ${REGISTRY_URL}

proxy:
    remoteurl: ${REGISTRY_URL}
    username: ${REGISTRY_USERNAME}
    password: ${REGISTRY_PASSWORD}
EOL

        # enable docker swarm mode so we can support docker stacks.
        if ! docker info | grep -q "Swarm: active"; then
            docker swarm init
        fi

        mkdir -p "${CACHES_DIR}/registry_images"

        # run a docker registry pull through cache on the management machine.
        if [ "$DEPLOY_MGMT_REGISTRY" = true ]; then
            if ! docker stack list | grep -q registry; then
                docker stack deploy -c management/registry_mirror.yml registry
            fi
        fi
    fi
fi

# this is our password generation mechanism. Relying on GPG for secure password generation
function new_pass {
    gpg --gen-random --armor 1 25
}

if [ "$VPS_HOSTING_TARGET" = lxd ]; then
    # first let's get the DISK_TO_USE and DATA_PLANE_MACVLAN_INTERFACE from the ss-config
    # which is set up during LXD cluster creation ss-cluster.
    LXD_SS_CONFIG_LINE="$(lxc network list --format csv | grep ss-config)"
    CONFIG_ITEMS="$(echo "$LXD_SS_CONFIG_LINE" | awk -F'"' '{print $2}')"
    DATA_PLANE_MACVLAN_INTERFACE="$(echo "$CONFIG_ITEMS" | cut -d ',' -f2)"
    DISK_TO_USE="$(echo "$CONFIG_ITEMS" | cut -d ',' -f3)"

    export DATA_PLANE_MACVLAN_INTERFACE="$DATA_PLANE_MACVLAN_INTERFACE"
    export DISK_TO_USE="$DISK_TO_USE"

    ./deployment/create_lxc_base.sh

fi

function run_domain {

    export VPS_HOSTING_TARGET="$VPS_HOSTING_TARGET"
    export RUN_CERT_RENEWAL="$RUN_CERT_RENEWAL"
    export BTC_CHAIN="$BTC_CHAIN"
    export UPDATE_BTCPAY="$UPDATE_BTCPAY"
    export MIGRATE_VPS="$MIGRATE_VPS"
    export RECONFIGURE_BTCPAY_SERVER="$RECONFIGURE_BTCPAY_SERVER"

    # iterate over all our server endpoints and provision them if needed.
    # www
    VPS_HOSTNAME=


    for VIRTUAL_MACHINE in www btcpayserver; do
        FQDN=

        # shellcheck disable=SC1091
        source ./shared.sh

        if [ ! -f "$SITE_PATH/site_definition" ]; then
            echo "ERROR: Something went wrong. Your site_definition is missing."
            exit 1
        fi

        source "$SITE_PATH/site_definition"

        # create the local packup path if it's not there!
        BACKUP_PATH_CREATED=false

        export BACKUP_PATH_CREATED="$BACKUP_PATH_CREATED"
        export MAC_ADDRESS_TO_PROVISION=
        export VPS_HOSTNAME="$VPS_HOSTNAME"
        export FQDN="$VPS_HOSTNAME.$DOMAIN_NAME"
        export VIRTUAL_MACHINE="$VIRTUAL_MACHINE"
        BACKUP_TIMESTAMP="$(date +"%Y-%m")"
        UNIX_BACKUP_TIMESTAMP="$(date +%s)"
        export REMOTE_BACKUP_PATH="$REMOTE_HOME/backups/$VIRTUAL_MACHINE/$BACKUP_TIMESTAMP"
        LOCAL_BACKUP_PATH="$SITE_PATH/backups/$VIRTUAL_MACHINE/$BACKUP_TIMESTAMP"
        export LOCAL_BACKUP_PATH="$LOCAL_BACKUP_PATH"

        export BACKUP_TIMESTAMP="$BACKUP_TIMESTAMP"
        export UNIX_BACKUP_TIMESTAMP="$UNIX_BACKUP_TIMESTAMP"

        export REMOTE_CERT_DIR="$REMOTE_CERT_BASE_DIR/$FQDN"
        
        if [ ! -d "$LOCAL_BACKUP_PATH" ]; then
            mkdir -p "$LOCAL_BACKUP_PATH"
            BACKUP_PATH_CREATED=true
            RESTORE_WWW_USERDATA=false
        fi

        DDNS_HOST=
        if [ "$VIRTUAL_MACHINE" = www ]; then
            if [ "$DEPLOY_WWW_SERVER" = false ] || [ "$USER_SKIP_WWW" = true ]; then
                continue
            fi

            VPS_HOSTNAME="$WWW_HOSTNAME"
            MAC_ADDRESS_TO_PROVISION="$WWW_MAC_ADDRESS"
            DDNS_HOST="$WWW_HOSTNAME"
            ROOT_DISK_SIZE_GB="$((ROOT_DISK_SIZE_GB + NEXTCLOUD_SPACE_GB))"
        elif [ "$VIRTUAL_MACHINE" = btcpayserver ] || [ "$USER_SKIP_BTCPAY" = true ]; then
            if [ "$DEPLOY_BTCPAY_SERVER" = false ]; then
                continue
            fi

            DDNS_HOST="$BTCPAY_HOSTNAME"
            VPS_HOSTNAME="$BTCPAY_HOSTNAME"
            MAC_ADDRESS_TO_PROVISION="$BTCPAY_MAC_ADDRESS"
            if [ "$BTC_CHAIN" = mainnet ]; then
                ROOT_DISK_SIZE_GB=150
            elif [ "$BTC_CHAIN" = testnet ]; then
                ROOT_DISK_SIZE_GB=70
            fi
        elif [ "$VIRTUAL_MACHINE" = "sovereign-stack" ]; then
            DDNS_HOST="sovereign-stack-base"
            ROOT_DISK_SIZE_GB=8
            MAC_ADDRESS_TO_PROVISION="$SOVEREIGN_STACK_MAC_ADDRESS"
        else
            echo "ERROR: VIRTUAL_MACHINE not within allowable bounds."
            exit
        fi

        export DDNS_HOST="$DDNS_HOST"
        export FQDN="$DDNS_HOST.$DOMAIN_NAME"
        export LXD_VM_NAME="${FQDN//./-}"
        export REMOTE_BACKUP_PATH="$REMOTE_BACKUP_PATH"

        # This next section of if statements is our sanity checking area.
        if [ "$VPS_HOSTING_TARGET" = aws ]; then
            # we require DDNS on AWS to set the public DNS to the right host.
            if [ -z "$DDNS_PASSWORD" ]; then
                echo "ERROR: Ensure DDNS_PASSWORD is configured in your site_definition."
                exit 1
            fi
        fi

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

        if [ -z "$DEPLOY_BTCPPAY_SERVER" ]; then
            echo "ERROR: Ensure DEPLOY_BTCPPAY_SERVER is configured in your site_definition."
            exit 1
        fi

        if [ -z "$NOSTR_ACCOUNT_PUBKEY" ]; then 
            echo "ERROR: You MUST specify a Nostr public key. This is how you get all your social features."
            echo "INFO: Go to your site_definition file and set the NOSTR_ACCOUNT_PUBKEY variable."
            exit 1
        fi
    
        MACHINE_EXISTS=false
        if [ "$VPS_HOSTING_TARGET" = aws ] && docker-machine ls -q | grep -q "$FQDN"; then
            MACHINE_EXISTS=true
        fi

        if [ "$VPS_HOSTING_TARGET" = lxd ] && lxc list --format csv | grep -q "$FQDN"; then
            MACHINE_EXISTS=true
        fi

        if [ "$USER_NO_BACKUP" = true ]; then
            RUN_BACKUP=false
        fi

        if [ "$MACHINE_EXISTS"  = true ]; then
            # we delete the machine if the user has directed us to
            if [ "$MIGRATE_VPS" = true ]; then
                
                # if the RESTORE_ARCHIVE is not set, then 
                if [ -z "$RESTORE_ARCHIVE" ]; then
                    RESTORE_ARCHIVE="$LOCAL_BACKUP_PATH/$UNIX_BACKUP_TIMESTAMP.tar.gz"
                fi

                # get a backup of the machine. This is what we restore to the new VPS.
                echo "INFO: Machine exists.  Since we're going to delete it, let's grab a backup. We don't need to restore services since we're deleting it."
                RESTORE_BTCPAY=false UPDATE_BTCPAY=false RUN_RESTORE=false RUN_BACKUP=true RUN_SERVICES=false ./deployment/domain_init.sh

                # delete the remote VPS.
                if [ "$VPS_HOSTING_TARGET" = aws ]; then
                    RESPONSE=
                    read -r -p "Do you want to continue with deleting '$FQDN' (y/n)": RESPONSE
                    if [ "$RESPONSE" = y ]; then
                        docker-machine rm -f "$FQDN"
                    else
                        echo "STOPPING the migration. User entered something other than 'y'."
                        exit 1
                    fi
                elif [ "$VPS_HOSTING_TARGET" = lxd ]; then
                    lxc delete --force "$LXD_VM_NAME"
                    USER_RUN_RESTORE=true
                fi

                # Then we run the script again to re-instantiate a new VPS, restoring all user data 
                # if restore directory doesn't exist, then we end up with a new site.
                echo "INFO: Recreating the remote VPS then restoring user data."
                sleep 5
                RESTORE_BTCPAY=true UPDATE_BTCPAY=false RUN_RESTORE=true RUN_BACKUP=false RUN_SERVICES=true RUN_CERT_RENEWAL=false RESTORE_ARCHIVE="$RESTORE_ARCHIVE" ./deployment/domain_init.sh
                sleep 5
            else
                RESTORE_BTCPAY="$RESTORE_BTCPAY" UPDATE_BTCPAY="$UPDATE_BTCPAY" RUN_RESTORE="$USER_RUN_RESTORE" RUN_BACKUP="$RUN_BACKUP" RUN_SERVICES=true ./deployment/domain_init.sh
            fi
        else
            if [ "$MIGRATE_VPS" = true ]; then
                echo "INFO: User has indicated to delete the machine, but it doesn't exist. Going to create it anyway."
            fi

            # The machine does not exist. Let's bring it into existence, restoring from latest backup.
            echo "Machine does not exist. RUN_RESTORE=$USER_RUN_RESTORE RUN_BACKUP=false" 
            RESTORE_BTCPAY="$RESTORE_BTCPAY" UPDATE_BTCPAY="$UPDATE_BTCPAY" RUN_RESTORE="$USER_RUN_RESTORE" RUN_BACKUP=false RUN_SERVICES=true ./deployment/domain_init.sh
        fi
    done

}

function stub_site_definition {

    export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"
    mkdir -p "$SITE_PATH"

    if [ -f "$SITE_PATH/site_definition" ]; then
            source ./shared.sh
    else

        # check to see if the enf file exists. exist if not.
        SITE_DEFINITION_PATH="$SITE_PATH/site_definition"
        if [ ! -f "$SITE_DEFINITION_PATH" ]; then

            # stub out a site_definition with new passwords.
            cat >"$SITE_DEFINITION_PATH" <<EOL
#!/bin/bash

# Set the domain name for the identity site.
export DOMAIN_NAME="${DOMAIN_NAME}"

# duplicitiy backup archive password
export DUPLICITY_BACKUP_PASSPHRASE="$(new_pass)"

# AWS only
#export DDNS_PASSWORD=

## WWW
export DEPLOY_WWW_SERVER=true

# Deploy APPS to www
export DEPLOY_GHOST=true
export DEPLOY_NEXTCLOUD=true
export DEPLOY_NOSTR=false

# set if NOSTR_ACCOUNT_PUBKEY=true
export NOSTR_ACCOUNT_PUBKEY="CHANGE_ME"

export DEPLOY_GITEA=false
export DEPLOY_ONION_SITE=false

# passwords for WWW apps
## GHOST
export GHOST_MYSQL_PASSWORD="$(new_pass)"
export GHOST_MYSQL_ROOT_PASSWORD="$(new_pass)"

## NEXTCLOUD
export NEXTCLOUD_MYSQL_PASSWORD="$(new_pass)"
export NEXTCLOUD_MYSQL_ROOT_PASSWORD="$(new_pass)"

## GITEA
export GITEA_MYSQL_PASSWORD="$(new_pass)"
export GITEA_MYSQL_ROOT_PASSWORD="$(new_pass)"

## BTCPAY SERVER; if true, then a BTCPay server is deployed.
export DEPLOY_BTCPAY_SERVER=false
export BTCPAYSERVER_MAC_ADDRESS="CHANGE_ME_REQUIRED"

# CHAIN to DEPLOY; valid are 'regtest', 'testnet', and 'mainnet'
export BTC_CHAIN=regtest

# set to false to disable nginx caching; helps when making website updates.
# export ENABLE_NGINX_CACHING=true

EOL

            chmod 0744 "$SITE_DEFINITION_PATH"
            echo "INFO: we stubbed a new site_defintion for you at '$SITE_DEFINITION_PATH'. Go update it yo!"
            exit 1

        fi
    fi

}

# let's iterate over the user-supplied domain list and provision each domain.
if [ "$VPS_HOSTING_TARGET" = lxd ]; then
    # iterate through our site list as provided by operator from cluster_definition
    for i in ${SITE_LIST//,/ }; do
        export DOMAIN_NAME="$i"
        export SITE_PATH=""

        stub_site_definition

        # run the logic for a domain deployment.
        run_domain

    done

elif [ "$VPS_HOSTING_TARGET" = aws ]; then
    stub_site_definition

    # if we're on AWS, we can just provision each system separately.
    run_domain
fi