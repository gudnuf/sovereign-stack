#!/bin/bash

set -exu
cd "$(dirname "$0")"

LATEST_GIT_COMMIT="$(cat ./project/.git/refs/heads/main)"
export LATEST_GIT_COMMIT="$LATEST_GIT_COMMIT"

# check to ensure dependencies are met.
for cmd in wait-for-it dig rsync sshfs lxc; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "This script requires \"${cmd}\" to be installed. Please run 'install.sh'."
        exit 1
    fi
done

# do a spot check; if we are on production warn.
if lxc remote get-default | grep -q "production"; then
    echo "WARNING: You are running command against a production system!"
    echo ""

    # check if there are any uncommited changes. It's dangerous to 
    # alter production systems when you have commits to make or changes to stash.
    if git update-index --refresh | grep -q "needs update"; then
        echo "ERROR: You have uncommited changes! You MUST commit or stash all changes to continue."
        exit 1
    fi

    RESPONSE=
    read -r -p "         Are you sure you want to continue (y)  ": RESPONSE
    if [ "$RESPONSE" != "y" ]; then
        echo "STOPPING."
        exit 1
    fi

fi


PRIMARY_DOMAIN=
RUN_CERT_RENEWAL=true
SKIP_BASE_IMAGE_CREATION=false
SKIP_WWW=false
RESTORE_WWW=false
RESTORE_CERTS=false
BACKUP_CERTS=false
BACKUP_BTCPAY=false
BACKUP_CERTS=false
BACKUP_APPS=false
BACKUP_BTCPAY=false
BACKUP_BTCPAY_ARCHIVE_PATH=
RESTORE_BTCPAY=false
SKIP_BTCPAY=false
UPDATE_BTCPAY=false
REMOTE_NAME="$(lxc remote get-default)"
STOP_SERVICES=false
USER_SAYS_YES=false
RESTART_FRONT_END=true

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --restore-certs)
            RESTORE_CERTS=true
            shift
        ;;
        --restore-www)
            RESTORE_WWW=true
            RESTORE_CERTS=true

            shift
        ;;
        --restore-btcpay)
            RESTORE_BTCPAY=true
            shift
        ;;
        --backup-www)
            BACKUP_CERTS=true
            BACKUP_APPS=true
            shift
        ;;
        --backup-btcpayserver)
            BACKUP_BTCPAY=true
            shift
        ;;
        --stop)
            STOP_SERVICES=true
            RESTART_FRONT_END=false
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
        --skip-btcpayserver)
            SKIP_BTCPAY=true
            shift
        ;;
        --skip-base-image)
            SKIP_BASE_IMAGE_CREATION=true
            shift
        ;;
        --no-cert-renew)
            RUN_CERT_RENEWAL=false
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
    echo "ERROR: Use the '--backup-archive-path=/path/to/btcpay/archive.tar.gz' option when restoring btcpay server."
    exit 1
fi

if [ "$RESTORE_BTCPAY" = true ] && [ ! -f "$BACKUP_BTCPAY_ARCHIVE_PATH" ]; then
    echo "ERROR: The backup archive path you specified DOES NOT exist!"
    exit 1
fi

. ./remote_env.sh

export REGISTRY_DOCKER_IMAGE="registry:2"
export RESTORE_WWW="$RESTORE_WWW"
export STOP_SERVICES="$STOP_SERVICES"
export BACKUP_CERTS="$BACKUP_CERTS"
export BACKUP_APPS="$BACKUP_APPS"
export RESTORE_BTCPAY="$RESTORE_BTCPAY"
export BACKUP_BTCPAY="$BACKUP_BTCPAY"
export RUN_CERT_RENEWAL="$RUN_CERT_RENEWAL"
export REMOTE_NAME="$REMOTE_NAME"
export REMOTE_PATH="$REMOTES_PATH/$REMOTE_NAME"
export USER_SAYS_YES="$USER_SAYS_YES"
export BACKUP_BTCPAY_ARCHIVE_PATH="$BACKUP_BTCPAY_ARCHIVE_PATH"
export RESTART_FRONT_END="$RESTART_FRONT_END"
export RESTORE_CERTS="$RESTORE_CERTS"

# todo convert this to Trezor-T
SSH_PUBKEY_PATH="$SSH_HOME/id_rsa.pub"
export SSH_PUBKEY_PATH="$SSH_PUBKEY_PATH"
if [ ! -f "$SSH_PUBKEY_PATH" ]; then
    # generate a new SSH key for the base vm image.
    ssh-keygen -f "$SSH_HOME/id_rsa" -t ecdsa -b 521 -N ""
fi

# ensure our remote path is created.
mkdir -p "$REMOTE_PATH"

REMOTE_DEFINITION="$REMOTE_PATH/remote.conf"
if [ ! -f "$REMOTE_DEFINITION" ]; then
    echo "ERROR: The remote definition could not be found. You may need to re-run 'ss-remote'."
    exit 1
fi

export REMOTE_DEFINITION="$REMOTE_DEFINITION"
source "$REMOTE_DEFINITION"
export LXD_REMOTE_PASSWORD="$LXD_REMOTE_PASSWORD"
export DEPLOYMENT_STRING="$DEPLOYMENT_STRING"

# this is our password generation mechanism. Relying on GPG for secure password generation
function new_pass {
    gpg --gen-random --armor 1 25
}


function stub_site_definition {
    mkdir -p "$SITE_PATH" "$PROJECT_PATH/sites"

    # create a symlink from the PROJECT_PATH/sites/DOMAIN_NAME to the ss-sites/domain name
    DOMAIN_SYMLINK_PATH="$PROJECT_PATH/sites/$DOMAIN_NAME"
    if [ ! -L "$DOMAIN_SYMLINK_PATH" ]; then
        ln -r -s "$SITE_PATH" "$DOMAIN_SYMLINK_PATH"
    fi

    if [ ! -f "$SITE_PATH/site.conf" ]; then
        # check to see if the enf file exists. exist if not.
        SITE_DEFINITION_PATH="$SITE_PATH/site.conf"
        if [ ! -f "$SITE_DEFINITION_PATH" ]; then

            # stub out a site.conf with new passwords.
            cat >"$SITE_DEFINITION_PATH" <<EOL
# https://www.sovereign-stack.org/ss-deploy/#siteconf

DOMAIN_NAME="${DOMAIN_NAME}"
# BTCPAY_ALT_NAMES="tip,store,pay,send"
SITE_LANGUAGE_CODES="en"
DUPLICITY_BACKUP_PASSPHRASE="$(new_pass)"
DEPLOY_GHOST=true
DEPLOY_CLAMS=false
DEPLOY_NEXTCLOUD=false
DEPLOY_NOSTR=false
NOSTR_ACCOUNT_PUBKEY=
DEPLOY_GITEA=false
GHOST_MYSQL_PASSWORD="$(new_pass)"
GHOST_MYSQL_ROOT_PASSWORD="$(new_pass)"
NEXTCLOUD_MYSQL_PASSWORD="$(new_pass)"
NEXTCLOUD_MYSQL_ROOT_PASSWORD="$(new_pass)"
GITEA_MYSQL_PASSWORD="$(new_pass)"
GITEA_MYSQL_ROOT_PASSWORD="$(new_pass)"

EOL

            chmod 0744 "$SITE_DEFINITION_PATH"
            echo "INFO: we stubbed a new site.conf for you at '$SITE_DEFINITION_PATH'. Go update it!"
            exit 1

        fi
    fi

}

PROJECT_NAME="$(lxc info | grep "project:" | awk '{print $2}')"
export PROJECT_NAME="$PROJECT_NAME"
export PROJECT_PATH="$PROJECTS_PATH/$PROJECT_NAME"

mkdir -p "$PROJECT_PATH" "$REMOTE_PATH/projects"

# create a symlink from ./remotepath/projects/project
PROJECT_SYMLINK="$REMOTE_PATH/projects/$PROJECT_NAME"
if [ ! -L "$PROJECT_SYMLINK" ]; then
    ln -r -s "$PROJECT_PATH" "$PROJECT_SYMLINK"
fi

# check to see if the enf file exists. exist if not.
PROJECT_DEFINITION_PATH="$PROJECT_PATH/project.conf"
if [ ! -f "$PROJECT_DEFINITION_PATH" ]; then

        # stub out a project.conf
    cat >"$PROJECT_DEFINITION_PATH" <<EOL
# see https://www.sovereign-stack.org/ss-deploy/#projectconf for more info.

PRIMARY_DOMAIN="domain0.tld"
# OTHER_SITES_LIST="domain1.tld,domain2.tld,domain3.tld"

WWW_SERVER_MAC_ADDRESS=
# WWW_SSDATA_DISK_SIZE_GB=100
# WWW_SERVER_CPU_COUNT="6"
# WWW_SERVER_MEMORY_MB="4096"

BTCPAYSERVER_MAC_ADDRESS=
# BTCPAY_SERVER_CPU_COUNT="4"
# BTCPAY_SERVER_MEMORY_MB="4096"

EOL

    chmod 0744 "$PROJECT_DEFINITION_PATH"
    echo "INFO: we stubbed a new project.conf for you at '$PROJECT_DEFINITION_PATH'. Go update it!"
    echo "INFO: Learn more at https://www.sovereign-stack.org/ss-deploy/"

    exit 1
fi

. ./project_env.sh

if [ -z "$PRIMARY_DOMAIN" ]; then
    echo "ERROR: The PRIMARY_DOMAIN is not specified. Check your project.conf."
    exit 1
fi

if [ -z "$WWW_SERVER_MAC_ADDRESS" ]; then
    echo "ERROR: the WWW_SERVER_MAC_ADDRESS is not specified. Check your project.conf."
    exit 1
fi


if [ -z "$BTCPAYSERVER_MAC_ADDRESS" ]; then
    echo "ERROR: the BTCPAYSERVER_MAC_ADDRESS is not specified. Check your project.conf."
    exit 1
fi

# the DOMAIN_LIST is a complete list of all our domains. We often iterate over this list.
DOMAIN_LIST="${PRIMARY_DOMAIN}"
if [ -n "$OTHER_SITES_LIST" ]; then
    DOMAIN_LIST="${DOMAIN_LIST},${OTHER_SITES_LIST}"
fi

export DOMAIN_LIST="$DOMAIN_LIST"
export DOMAIN_COUNT=$(("$(echo "$DOMAIN_LIST" | tr -cd , | wc -c)"+1))

# let's provision our primary domain first.
export DOMAIN_NAME="$PRIMARY_DOMAIN"
export PRIMARY_DOMAIN="$PRIMARY_DOMAIN"
export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"
export PRIMARY_WWW_FQDN="$WWW_HOSTNAME.$DOMAIN_NAME"

stub_site_definition

# bring the VMs up under the primary domain name.

export UPDATE_BTCPAY="$UPDATE_BTCPAY"

# iterate over all our server endpoints and provision them if needed.
# www
VPS_HOSTNAME=

if ! lxc image list --format csv | grep -q "$DOCKER_BASE_IMAGE_NAME"; then
    # create the lxd base image.
    if [ "$SKIP_BASE_IMAGE_CREATION" = false ]; then
        ./create_lxc_base.sh
    fi
fi

for VIRTUAL_MACHINE in www btcpayserver; do

    if [ "$VIRTUAL_MACHINE" = btcpayserver ] && [ "$SKIP_BTCPAY" = true ]; then
        continue
    fi

    if [ "$VIRTUAL_MACHINE" = www ] && [ "$SKIP_WWW" = true ]; then
        continue
    fi


    export VIRTUAL_MACHINE="$VIRTUAL_MACHINE"
    FQDN=

    export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"

    source "$SITE_PATH/site.conf"
    source ./project/domain_env.sh

    # VALIDATE THE INPUT from the ENVFILE
    if [ -z "$DOMAIN_NAME" ]; then
        echo "ERROR: DOMAIN_NAME not specified in your site.conf."
        exit 1
    fi

    # Goal is to get the macvlan interface.
    LXD_SS_CONFIG_LINE=
    if lxc network list --format csv --project=default | grep lxdbr0 | grep -q "ss-config"; then
        LXD_SS_CONFIG_LINE="$(lxc network list --format csv --project=default | grep lxdbr0 | grep ss-config)"
    fi

    if [ -z "$LXD_SS_CONFIG_LINE" ]; then
        echo "ERROR: the MACVLAN interface has not been specified. You may need to run 'ss-remote' again."
        exit 1
    fi

    CONFIG_ITEMS="$(echo "$LXD_SS_CONFIG_LINE" | awk -F'"' '{print $2}')"
    DATA_PLANE_MACVLAN_INTERFACE="$(echo "$CONFIG_ITEMS" | cut -d ',' -f2)"
    export DATA_PLANE_MACVLAN_INTERFACE="$DATA_PLANE_MACVLAN_INTERFACE"


    # Now let's switch to the new project to ensure new resources are created under the project scope.
    if ! lxc info | grep "project:" | grep -q "$PROJECT_NAME"; then
        lxc project switch "$PROJECT_NAME"
    fi

    # check if the OVN network exists in this project.
    if ! lxc network list | grep -q "ss-ovn"; then
        lxc network create ss-ovn --type=ovn network=lxdbr1 ipv6.address=none
    fi

    export MAC_ADDRESS_TO_PROVISION=
    export VPS_HOSTNAME="$VPS_HOSTNAME"
    export FQDN="$VPS_HOSTNAME.$DOMAIN_NAME"

    if [ "$VIRTUAL_MACHINE" = www ]; then
        if [ "$SKIP_WWW" = true ]; then
            echo "INFO: Skipping WWW due to command line argument."
            continue
        fi
        
        FQDN="$WWW_HOSTNAME.$DOMAIN_NAME"
        VPS_HOSTNAME="$WWW_HOSTNAME"
        MAC_ADDRESS_TO_PROVISION="$WWW_SERVER_MAC_ADDRESS"

    elif [ "$VIRTUAL_MACHINE" = btcpayserver ] || [ "$SKIP_BTCPAY" = true ]; then
        FQDN="$BTCPAY_HOSTNAME.$DOMAIN_NAME"
        VPS_HOSTNAME="$BTCPAY_HOSTNAME"
        MAC_ADDRESS_TO_PROVISION="$BTCPAYSERVER_MAC_ADDRESS"

    elif [ "$VIRTUAL_MACHINE" = "$BASE_IMAGE_VM_NAME" ]; then
        export FQDN="$BASE_IMAGE_VM_NAME"
    else
        echo "ERROR: VIRTUAL_MACHINE not within allowable bounds."
        exit
    fi

    export FQDN="$FQDN"
    export LXD_VM_NAME="${FQDN//./-}"
    export MAC_ADDRESS_TO_PROVISION="$MAC_ADDRESS_TO_PROVISION"
    export PROJECT_PATH="$PROJECT_PATH"

    ./deploy_vm.sh

    if [ "$VIRTUAL_MACHINE" = www ]; then
        # this tells our local docker client to target the remote endpoint via SSH
        export DOCKER_HOST="ssh://ubuntu@$PRIMARY_WWW_FQDN"

        # enable docker swarm mode so we can support docker stacks.
        if docker info | grep -q "Swarm: inactive"; then
            docker swarm init --advertise-addr enp6s0
        fi
    fi
    
done

# let's stub out the rest of our site definitions, if any.
for DOMAIN_NAME in ${OTHER_SITES_LIST//,/ }; do
    export DOMAIN_NAME="$DOMAIN_NAME"
    export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"

    # stub out the site_defition if it's doesn't exist.
    stub_site_definition
done


# now let's run the www and btcpay-specific provisioning scripts.
if [ "$SKIP_WWW" = false ]; then
    ./project/www/go.sh
    ssh ubuntu@"$PRIMARY_WWW_FQDN" "echo $LATEST_GIT_COMMIT > /home/ubuntu/.ss-githead"
else
    echo "INFO: Skipping www VM."
fi

export DOMAIN_NAME="$PRIMARY_DOMAIN"
export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"
if [ "$SKIP_BTCPAY" = false ]; then
    ./project/btcpayserver/go.sh

    ssh ubuntu@"$BTCPAY_FQDN" "echo $LATEST_GIT_COMMIT > /home/ubuntu/.ss-githead"
else
    echo "INFO: Skipping the btcpayserver VM."
fi