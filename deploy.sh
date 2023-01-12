#!/bin/bash

set -e
cd "$(dirname "$0")"

RESPOSITORY_PATH="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
export RESPOSITORY_PATH="$RESPOSITORY_PATH"

./check_dependencies.sh

DOMAIN_NAME=
RUN_CERT_RENEWAL=true
SKIP_WWW=false
RESTORE_WWW=false
BACKUP_CERTS=true
BACKUP_APPS=true
BACKUP_BTCPAY=true
BACKUP_BTCPAY_ARCHIVE_PATH=
RESTORE_BTCPAY=false
SKIP_BTCPAY=false
UPDATE_BTCPAY=false
RECONFIGURE_BTCPAY_SERVER=false
CLUSTER_NAME="$(lxc remote get-default)"
STOP_SERVICES=false
USER_SAYS_YES=false
RESTART_FRONT_END=true

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --restore-www)
            RESTORE_WWW=true
            BACKUP_APPS=false
            RUN_CERT_RENEWAL=false
            RESTART_FRONT_END=true
            shift
        ;;
        --restore-btcpay)
            RESTORE_BTCPAY=true
            BACKUP_BTCPAY=false
            RUN_CERT_RENEWAL=false
            shift
        ;;
        --backup-certs)
            BACKUP_CERTS=true
            shift
        ;;
        --no-backup-www)
            BACKUP_CERTS=false
            BACKUP_APPS=false
            shift
        ;;
        --stop)
            STOP_SERVICES=true
            RESTART_FRONT_END=true
            shift
        ;;
        --restart-front-end)
            RESTART_FRONT_END=true
            shift
        ;;
        --domain=*)
            DOMAIN_NAME="${i#*=}"
            shift
        ;;
        --backup-archive-path=*)
            BACKUP_BTCPAY_ARCHIVE_PATH="${i#*=}"
            shift
        ;;
        --update-btcpay)
            UPDATE_BTCPAY=true
            shift
        ;;
        --skip-www)
            SKIP_WWW=true
            shift
        ;;
        --skip-btcpay)
            SKIP_BTCPAY=true
            shift
        ;;
        --backup-ghost)
            BACKUP_APPS=true
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
        -y)
            USER_SAYS_YES=true
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

if [ "$RESTORE_BTCPAY" = true ] && [ -z "$BACKUP_BTCPAY_ARCHIVE_PATH" ]; then
    echo "ERROR: BACKUP_BTCPAY_ARCHIVE_PATH was not set event when the RESTORE_BTCPAY = true. "
    exit 1
fi

# set up our default paths.
source ./defaults.sh

export DOMAIN_NAME="$DOMAIN_NAME"
export REGISTRY_DOCKER_IMAGE="registry:2"
export RESTORE_WWW="$RESTORE_WWW"
export STOP_SERVICES="$STOP_SERVICES"
export BACKUP_CERTS="$BACKUP_CERTS"
export BACKUP_APPS="$BACKUP_APPS"
export RESTORE_BTCPAY="$RESTORE_BTCPAY"
export BACKUP_BTCPAY="$BACKUP_BTCPAY"
export RUN_CERT_RENEWAL="$RUN_CERT_RENEWAL"
export CLUSTER_NAME="$CLUSTER_NAME"
export CLUSTER_PATH="$CLUSTERS_DIR/$CLUSTER_NAME"
export USER_SAYS_YES="$USER_SAYS_YES"
export BACKUP_BTCPAY_ARCHIVE_PATH="$BACKUP_BTCPAY_ARCHIVE_PATH"
export RESTART_FRONT_END="$RESTART_FRONT_END"


# ensure our cluster path is created.
mkdir -p "$CLUSTER_PATH"

# if an authorized_keys file does not exist, we'll stub one out with the current user.
# add additional id_rsa.pub entries manually for more administrative logins.
if [ ! -f "$CLUSTER_PATH/authorized_keys" ]; then
    cat "$SSH_HOME/id_rsa.pub" >> "$CLUSTER_PATH/authorized_keys"
    echo "INFO: Sovereign Stack just stubbed out '$CLUSTER_PATH/authorized_keys'. Go update it."
    echo "      Add ssh pubkeys for your various management machines, if any."
    echo "      By default we added your main ssh pubkey: '$SSH_HOME/id_rsa.pub'."
    exit 1
fi


CLUSTER_DEFINITION="$CLUSTER_PATH/cluster_definition"
export CLUSTER_DEFINITION="$CLUSTER_DEFINITION"

#########################################
if [ ! -f "$CLUSTER_DEFINITION" ]; then
    echo "ERROR: The cluster definition could not be found. You may need to re-run 'ss-cluster create'."
    exit 1
fi

source "$CLUSTER_DEFINITION"

# this is our password generation mechanism. Relying on GPG for secure password generation
function new_pass {
    gpg --gen-random --armor 1 25
}

function instantiate_vms {

    export BTC_CHAIN="$BTC_CHAIN"
    export UPDATE_BTCPAY="$UPDATE_BTCPAY"
    export RECONFIGURE_BTCPAY_SERVER="$RECONFIGURE_BTCPAY_SERVER"

    # iterate over all our server endpoints and provision them if needed.
    # www
    VPS_HOSTNAME=

    for VIRTUAL_MACHINE in www btcpayserver; do
        export VIRTUAL_MACHINE="$VIRTUAL_MACHINE"
        FQDN=

        export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"

        source "$SITE_PATH/site_definition"
        source "$RESPOSITORY_PATH/domain_env.sh"

        # VALIDATE THE INPUT from the ENVFILE
        if [ -z "$DOMAIN_NAME" ]; then
            echo "ERROR: DOMAIN_NAME not specified. Use the --domain-name= option."
            exit 1
        fi


        # first let's get the DISK_TO_USE and DATA_PLANE_MACVLAN_INTERFACE from the ss-config
        # which is set up during LXD cluster creation ss-cluster.
        LXD_SS_CONFIG_LINE=
        if lxc network list --format csv | grep lxdbrSS | grep -q ss-config; then
            LXD_SS_CONFIG_LINE="$(lxc network list --format csv | grep lxdbrSS | grep ss-config)"
        fi

        if [ -z "$LXD_SS_CONFIG_LINE" ]; then
            echo "ERROR: the MACVLAN interface has not been specified. You may need to run ss-cluster again."
            exit 1
        fi

        CONFIG_ITEMS="$(echo "$LXD_SS_CONFIG_LINE" | awk -F'"' '{print $2}')"
        DATA_PLANE_MACVLAN_INTERFACE="$(echo "$CONFIG_ITEMS" | cut -d ',' -f2)"
        DISK_TO_USE="$(echo "$CONFIG_ITEMS" | cut -d ',' -f3)"

        export DATA_PLANE_MACVLAN_INTERFACE="$DATA_PLANE_MACVLAN_INTERFACE"
        export DISK_TO_USE="$DISK_TO_USE"

        ./deployment/create_lxc_base.sh

        export MAC_ADDRESS_TO_PROVISION=
        export VPS_HOSTNAME="$VPS_HOSTNAME"
        export FQDN="$VPS_HOSTNAME.$DOMAIN_NAME"

        # ensure the admin has set the MAC address for the base image.
        if [ -z "$SOVEREIGN_STACK_MAC_ADDRESS" ]; then
            echo "ERROR: SOVEREIGN_STACK_MAC_ADDRESS is undefined. Check your project definition."
            exit 1
        fi

        DDNS_HOST=

        if [ "$VIRTUAL_MACHINE" = www ]; then
            if [ "$SKIP_WWW" = true ]; then
                echo "INFO: Skipping WWW due to command line argument."
                continue
            fi

            VPS_HOSTNAME="$WWW_HOSTNAME"
            MAC_ADDRESS_TO_PROVISION="$WWW_SERVER_MAC_ADDRESS"
            DDNS_HOST="$WWW_HOSTNAME"
            ROOT_DISK_SIZE_GB="$((ROOT_DISK_SIZE_GB + NEXTCLOUD_SPACE_GB))"
        elif [ "$VIRTUAL_MACHINE" = btcpayserver ] || [ "$SKIP_BTCPAY" = true ]; then
            DDNS_HOST="$BTCPAY_HOSTNAME"
            VPS_HOSTNAME="$BTCPAY_HOSTNAME"
            MAC_ADDRESS_TO_PROVISION="$BTCPAYSERVER_MAC_ADDRESS"
            if [ "$BTC_CHAIN" = mainnet ]; then
                ROOT_DISK_SIZE_GB=150
            elif [ "$BTC_CHAIN" = testnet ]; then
                ROOT_DISK_SIZE_GB=70
            fi

        elif [ "$VIRTUAL_MACHINE" = "sovereign-stack" ]; then
            DDNS_HOST="sovereign-stack-base"
            ROOT_DISK_SIZE_GB=8
        else
            echo "ERROR: VIRTUAL_MACHINE not within allowable bounds."
            exit
        fi

        export DDNS_HOST="$DDNS_HOST"
        export FQDN="$DDNS_HOST.$DOMAIN_NAME"
        export LXD_VM_NAME="${FQDN//./-}"
        export VIRTUAL_MACHINE="$VIRTUAL_MACHINE"
        export REMOTE_CERT_DIR="$REMOTE_CERT_BASE_DIR/$FQDN"
        export MAC_ADDRESS_TO_PROVISION="$MAC_ADDRESS_TO_PROVISION"
        ./deployment/deploy_vms.sh

        # if the local docker client isn't logged in, do so;
        # this helps prevent docker pull errors since they throttle.
        # if [ ! -f "$HOME/.docker/config.json" ]; then
        #     echo "$REGISTRY_PASSWORD" | docker login --username "$REGISTRY_USERNAME" --password-stdin
        # fi

        # this tells our local docker client to target the remote endpoint via SSH
        export DOCKER_HOST="ssh://ubuntu@$PRIMARY_WWW_FQDN"

        # enable docker swarm mode so we can support docker stacks.
        if docker info | grep -q "Swarm: inactive"; then
            docker swarm init --advertise-addr enp6s0
        fi

    done

}


function stub_site_definition {
    mkdir -p "$SITE_PATH" "$PROJECT_PATH/sites"

    # create a symlink from the CLUSTERPATH/sites/DOMAIN_NAME to the ss-sites/domain name
    if [ ! -d "$PROJECT_PATH/sites/$DOMAIN_NAME" ]; then
        ln -s "$SITE_PATH" "$PROJECT_PATH/sites/$DOMAIN_NAME"
    fi

    if [ ! -f "$SITE_PATH/site_definition" ]; then
        # check to see if the enf file exists. exist if not.
        SITE_DEFINITION_PATH="$SITE_PATH/site_definition"
        if [ ! -f "$SITE_DEFINITION_PATH" ]; then

            # stub out a site_definition with new passwords.
            cat >"$SITE_DEFINITION_PATH" <<EOL
#!/bin/bash

export DOMAIN_NAME="${DOMAIN_NAME}"
#export BTCPAY_ALT_NAMES="tip,store,pay,send"
export SITE_LANGUAGE_CODES="en"
export DUPLICITY_BACKUP_PASSPHRASE="$(new_pass)"
export DEPLOY_GHOST=true
export DEPLOY_NEXTCLOUD=false
export NOSTR_ACCOUNT_PUBKEY="NOSTR_IDENTITY_PUBKEY_GOES_HERE"
export DEPLOY_GITEA=false
export GHOST_MYSQL_PASSWORD="$(new_pass)"
export GHOST_MYSQL_ROOT_PASSWORD="$(new_pass)"
export NEXTCLOUD_MYSQL_PASSWORD="$(new_pass)"
export NEXTCLOUD_MYSQL_ROOT_PASSWORD="$(new_pass)"
export GITEA_MYSQL_PASSWORD="$(new_pass)"
export GITEA_MYSQL_ROOT_PASSWORD="$(new_pass)"

EOL

            chmod 0744 "$SITE_DEFINITION_PATH"
            echo "INFO: we stubbed a new site_definition for you at '$SITE_DEFINITION_PATH'. Go update it yo!"
            exit 1

        fi
    fi

}

CURRENT_PROJECT="$(lxc info | grep "project:" | awk '{print $2}')"
PROJECT_PATH="$PROJECTS_DIR/$PROJECT_NAME"
mkdir -p "$PROJECT_PATH" "$CLUSTER_PATH/projects"
export PROJECT_PATH="$PROJECT_PATH"

# create a symlink from ./clusterpath/projects/project
if [ ! -d "$CLUSTER_PATH/projects/$PROJECT_NAME" ]; then
    ln -s "$PROJECT_PATH" "$CLUSTER_PATH/projects/$PROJECT_NAME"
fi

# check if we need to provision a new lxc project.
if [ "$PROJECT_NAME" != "$CURRENT_PROJECT" ]; then
    if ! lxc project list | grep -q "$PROJECT_NAME"; then
        echo "INFO: The lxd project specified in the cluster_definition did not exist. We'll create one!"
        lxc project create "$PROJECT_NAME"
    fi

    echo "INFO: switch to lxd project '$PROJECT_NAME'."
    lxc project switch "$PROJECT_NAME"

fi


# check to see if the enf file exists. exist if not.
PROJECT_DEFINITION_PATH="$PROJECT_PATH/project_definition"
if [ ! -f "$PROJECT_DEFINITION_PATH" ]; then

    # stub out a project_definition
    cat >"$PROJECT_DEFINITION_PATH" <<EOL
#!/bin/bash

# see https://www.sovereign-stack.org/project-definition for more info.

export WWW_SERVER_MAC_ADDRESS="CHANGE_ME_REQUIRED"
export BTCPAYSERVER_MAC_ADDRESS="CHANGE_ME_REQUIRED"
export BTC_CHAIN="regtest|testnet|mainnet"
export PRIMARY_DOMAIN="domain0.tld"
export OTHER_SITES_LIST="domain1.tld,domain2.tld,domain3.tld"
export BTCPAY_SERVER_CPU_COUNT="4"
export BTCPAY_SERVER_MEMORY_MB="4096"
export WWW_SERVER_CPU_COUNT="6"
export WWW_SERVER_MEMORY_MB="4096"

EOL

    chmod 0744 "$PROJECT_DEFINITION_PATH"
    echo "INFO: we stubbed a new project_defition for you at '$PROJECT_DEFINITION_PATH'. Go update it yo!"
    echo "INFO: Learn more at https://www.sovereign-stack.org/project-definitions/"

    exit 1
fi

# source project defition.
source "$PROJECT_DEFINITION_PATH"

# the DOMAIN_LIST is a complete list of all our domains. We often iterate over this list.
DOMAIN_LIST="${PRIMARY_DOMAIN}"
if [ -n "$OTHER_SITES_LIST" ]; then
    DOMAIN_LIST="${DOMAIN_LIST},${OTHER_SITES_LIST}"
fi

export DOMAIN_LIST="$DOMAIN_LIST"
export DOMAIN_COUNT=$(("$(echo "$DOMAIN_LIST" | tr -cd , | wc -c)"+1))

# let's provision our primary domain first.
export DOMAIN_NAME="$PRIMARY_DOMAIN"

# we deploy the WWW and btcpay server under the PRIMARY_DOMAIN.
export DEPLOY_WWW_SERVER=true
export DEPLOY_BTCPAY_SERVER=true

export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"
export PRIMARY_WWW_FQDN="$WWW_HOSTNAME.$DOMAIN_NAME"

stub_site_definition

# bring the VMs up under the primary domain name.
instantiate_vms

# let's stub out the rest of our site definitions, if any.
for DOMAIN_NAME in ${OTHER_SITES_LIST//,/ }; do
    export DOMAIN_NAME="$DOMAIN_NAME"
    export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"

    # stub out the site_defition if it's doesn't exist.
    stub_site_definition
done

# now let's run the www and btcpay-specific provisioning scripts.
if [ "$SKIP_WWW" = false ] && [ "$DEPLOY_BTCPAY_SERVER" = true ]; then
    bash -c "./deployment/www/go.sh"
fi

export DOMAIN_NAME="$PRIMARY_DOMAIN"
export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"
if [ "$SKIP_BTCPAY" = false ] && [ "$DEPLOY_BTCPAY_SERVER" = true ]; then
    bash -c "./deployment/btcpayserver/go.sh"
fi
