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
check_dependencies wait-for-it dig rsync sshfs lxc docker-machine duplicity
# TODO remove dependency on Docker-machine. That's what we use to provision VM on 3rd party vendors. Looking for LXD endpoint.

MIGRATE_VPS=false
DOMAIN_NAME=
VPS_HOSTING_TARGET=lxd
RUN_CERT_RENEWAL=true
USER_NO_BACKUP=false
USER_RUN_RESTORE=false
BTC_CHAIN=regtest
UPDATE_BTCPAY=false
RECONFIGURE_BTCPAY_SERVER=false
DEPLOY_BTCPAY_SERVER=false
MACVLAN_INTERFACE=
LXD_DISK_TO_USE=

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --aws)
            VPS_HOSTING_TARGET=aws
            shift
        ;;
        --restore)
            USER_RUN_RESTORE=true
            RUN_CERT_RENEWAL=false
            USER_NO_BACKUP=true
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
        --no-backup)
            USER_NO_BACKUP=true
            shift
        ;;
        --migrate)
            MIGRATE_VPS=true
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
        --testnet)
            BTC_CHAIN=testnet
            shift
        ;;
        --regtest)
            BTC_CHAIN=regtest
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

# set up our default paths.
export CLUSTERS_DIR="$HOME/ss-clusters"
export CACHES_DIR="$HOME/ss-cache"
export SSH_HOME="$HOME/.ssh"
export DOMAIN_NAME="$DOMAIN_NAME"
export REGISTRY_DOCKER_IMAGE="registry:2"

if [ "$VPS_HOSTING_TARGET" = lxd ]; then
    CURRENT_REMOTE="$(lxc remote get-default)"
elif [ "$VPS_HOSTING_TARGET" = aws ]; then
    CURRENT_REMOTE="docker-machine"
fi

export LXD_REMOTE_PATH="$CLUSTERS_DIR/$CURRENT_REMOTE"
export CURRENT_REMOTE="$CURRENT_REMOTE"


# if an authorized_keys file does not exist, we'll stub one out with the current user.
# add additional id_rsa.pub entries manually for more administrative logins.
if [ ! -f "$LXD_REMOTE_PATH/authorized_keys" ]; then
    mkdir -p "u"
    cat "$SSH_HOME/id_rsa.pub" >> "$LXD_REMOTE_PATH/authorized_keys"
    echo "INFO: Sovereign Stack just stubbed out '$LXD_REMOTE_PATH/authorized_keys'. Go update it."
    echo "      Add ssh pubkeys for your various management machines, if any. We've stubbed it out"
    echo "      with your ssh pubkey at '$HOME/.ssh/id_rsa.pub'."
    exit 1
fi

if [ "$VPS_HOSTING_TARGET" = lxd ]; then
    mkdir -p "$CACHES_DIR" "$LXD_REMOTE_PATH"
    CLUSTER_DEFINTION="$LXD_REMOTE_PATH/cluster_definition"
    export CLUSTER_DEFINTION="$CLUSTER_DEFINTION"
    
    if [ ! -f "$CLUSTER_DEFINTION" ]; then
        # stub out a cluster_definition.
    cat >"$CLUSTER_DEFINTION" <<EOL
#!/bin/bash

# Note: the path above ./ corresponds to your LXD Remote. If your remote is set to 'cluster1'
# Then $HOME/clusters/cluster1 will be your cluster working path.

# This is REQUIRED. A list of all sites in ~/sites/ that will be deployed. 
# e.g., 'domain1.tld,domain2.tld,domain3.tld'
SITE_LIST="domain1.tld"

# REQUIRED - change the MACVLAN_INTERFACE to the host adapter that attaches to the SERVERS LAN segment/VLAN/subnet.
MACVLAN_INTERFACE="REQUIRED_CHANGE_ME"
LXD_DISK_TO_USE=""

# Deploy a registry cache on your management machine.
DEPLOY_REGISTRY=true

# only relevant
export REGISTRY_URL="http://\$HOSTNAME:5000"
export REGISTRY_USERNAME=<USERNAME TO DOCKERHUB.COM>
export REGISTRY_PASSWORD=<PASSWORD TO DOCKERHUB.COM>

export MACVLAN_INTERFACE="\$MACVLAN_INTERFACE"
export LXD_DISK_TO_USE="\$LXD_DISK_TO_USE"
export SITE_LIST="\$SITE_LIST"

EOL

        chmod 0744 "$CLUSTER_DEFINTION"
        echo "We stubbed out a '$CLUSTER_DEFINTION' file for you."
        echo "Use this file to customize your cluster deployment;"
        echo "Check out 'https://www.sovereign-stack.org/cluster-definition' for an example."
        exit 1
    fi

    #########################################
    if [ ! -f "$CLUSTER_DEFINTION" ]; then
        echo "ERROR: CLUSTER DEFINITION NOT PRESENT."
        exit 1
    fi
        
    source "$CLUSTER_DEFINTION"

    ###########################3
    # # This section is done to the management machine. We deploy a registry pull through cache on port 5000
    # if ! docker volume list | grep -q registry_data; then
    #     docker volume create registry_data
    # fi

    # if the registry URL isn't defined, then we just use the upstream dockerhub.
    # recommended to run a registry cache on your management machine though.
    if [ -n "$REGISTRY_URL" ]; then

cat > "$LXD_REMOTE_PATH/registry.yml" <<EOL
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

        # run a docker reigstry pull through cache on the management 
        if ! docker stack list | grep -q registry; then
            docker stack deploy -c management/registry_mirror.yml registry
        fi
    fi
fi

        
function new_pass {
    apg -a 1 -M nc -n 3 -m 26 -E GHIJKLMNOPQRSTUVWXYZ | head -n1 | awk '{print $1;}'
}

function run_domain {

    export VPS_HOSTING_TARGET="$VPS_HOSTING_TARGET"
    export LXD_DISK_TO_USE="$LXD_DISK_TO_USE"
    export RUN_CERT_RENEWAL="$RUN_CERT_RENEWAL"

    export BTC_CHAIN="$BTC_CHAIN"
    export UPDATE_BTCPAY="$UPDATE_BTCPAY"
    export MIGRATE_VPS="$MIGRATE_VPS"
    export RECONFIGURE_BTCPAY_SERVER="$RECONFIGURE_BTCPAY_SERVER"
    export MACVLAN_INTERFACE="$MACVLAN_INTERFACE"
    export LXD_DISK_TO_USE="$LXD_DISK_TO_USE"

    source ./defaults.sh
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

        # create the local packup path if it's not there!
        BACKUP_PATH_CREATED=false
        if [ ! -d "$LOCAL_BACKUP_PATH" ]; then
            mkdir -p "$LOCAL_BACKUP_PATH"
            BACKUP_PATH_CREATED=true
        fi

        export BACKUP_PATH_CREATED="$BACKUP_PATH_CREATED"
        export MAC_ADDRESS_TO_PROVISION="$MAC_ADDRESS_TO_PROVISION"
        export VPS_HOSTNAME="$VPS_HOSTNAME"
        export FQDN="$VPS_HOSTNAME.$DOMAIN_NAME"

        # generate the docker yaml and nginx configs.
        bash -c ./deployment/stub_docker_yml.sh
        bash -c ./deployment/stub_nginxconf.sh

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
                    RUN_RESTORE=false RUN_BACKUP=true RUN_SERVICES=false "$(pwd)/deployment/domain_init.sh"
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
                RUN_RESTORE="$USER_RUN_RESTORE" RUN_BACKUP=false RUN_SERVICES=true "$(pwd)/deployment/domain_init.sh"
            else
                if [ "$USER_NO_BACKUP"  = true ]; then
                    RUN_BACKUP=false
                    echo "INFO: Maintaining existing VPS. RUN_BACKUP=$RUN_BACKUP RUN_RESTORE=$USER_RUN_RESTORE"
                else
                    RUN_BACKUP=true
                    echo "INFO: Maintaining existing VPS. RUN_BACKUP=$RUN_BACKUP RUN_RESTORE=$USER_RUN_RESTORE"
                fi

                RUN_RESTORE="$USER_RUN_RESTORE" RUN_BACKUP="$RUN_BACKUP" RUN_SERVICES=true "$(pwd)/deployment/domain_init.sh"
            fi
        else
            if [ "$MIGRATE_VPS" = true ]; then
                echo "INFO: User has indicated to delete the machine, but it doesn't exist. Going to create it anyway."
            fi

            # The machine does not exist. Let's bring it into existence, restoring from latest backup.
            echo "Machine does not exist. RUN_RESTORE=$USER_RUN_RESTORE RUN_BACKUP=false" 
            RUN_RESTORE="$USER_RUN_RESTORE" RUN_BACKUP=false RUN_SERVICES=true "$(pwd)/deployment/domain_init.sh"
        fi
    done

}


function stub_site_definition {

    source ./defaults.sh

    if [ -f "$SITE_PATH/site_definition" ]; then
        source "$SITE_PATH/site_definition"
    else

        # check to see if the enf file exists. exist if not.
        SITE_DEFINITION_PATH="$SITE_PATH/site_definition"
        if [ ! -f "$SITE_DEFINITION_PATH" ]; then

            # stub out a site_definition with new passwords.
            cat >"$SITE_DEFINITION_PATH" <<EOL
#!/bin/bash

# Set the domain name for the identity site.
export DOMAIN_NAME="domain.tld"

# duplicitiy backup archive password
export DUPLICITY_BACKUP_PASSPHRASE="$(new_pass)"

# AWS only
#export DDNS_PASSWORD=
#export SMTP_PASSWORD=

## WWW
export DEPLOY_WWW_SERVER=true

# REQUIRED - CHANGE ME - RESERVE ME IN DHCP
export WWW_MAC_ADDRESS="CHANGE_ME"

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

# REQUIRED if DEPLOY_BTCPAY_SERVER=true
#export BTCPAY_MAC_ADDRESS="CHANGE_ME"

## BTCPAY Server
export DEPLOY_UMBREL_VPS=false

# REQUIRED if DEPLOY_UMBREL_VPS=true
#export UMBREL_MAC_ADDRESS="CHANGE_ME"

# CHAIN to DEPLOY; valid are 'testnet' and 'mainnet'
export BTC_CHAIN=regtest

EOL

            chmod 0744 "$SITE_DEFINITION_PATH"
            echo "INFO: we stubbed a new site_defintion for you at '$SITE_DEFINITION_PATH'. Go update it yo!"
            exit 1

        fi
    fi

}

if [ "$VPS_HOSTING_TARGET" = lxd ]; then
    # iterate through our site list as provided by operator from cluster_definition
    for i in ${SITE_LIST//,/ }; do
        export DOMAIN_NAME="$i"

        stub_site_definition

        # run the logic for a domain deployment.
        run_domain

    done

elif [ "$VPS_HOSTING_TARGET" = aws ]; then
    stub_site_definition

    # if we're on AWS, we can just provision each system separately.
    run_domain
fi