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

DOMAIN_NAME=
RESTORE_ARCHIVE=
VPS_HOSTING_TARGET=lxd
RUN_CERT_RENEWAL=false
RESTORE_WWW=false
BACKUP_CERTS=true
BACKUP_APPS=false
BACKUP_BTCPAY=false
RESTORE_BTCPAY=false
MIGRATE_WWW=false
MIGRATE_BTCPAY=false
SKIP_WWW=false
SKIP_BTCPAY=false
UPDATE_BTCPAY=false
RECONFIGURE_BTCPAY_SERVER=false
CLUSTER_NAME="$(lxc remote get-default)"
STOP_SERVICES=false

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --aws)
            VPS_HOSTING_TARGET=aws
            shift
        ;;
        --restore-www)
            RESTORE_WWW=true
            BACKUP_APPS=false
            RUN_CERT_RENEWAL=false
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
        --stop)
            STOP_SERVICES=true
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
        --backup-btcpay)
            BACKUP_BTCPAY=true
            shift
        ;;
        --migrate-www)
            MIGRATE_WWW=true
            RUN_CERT_RENEWAL=false
            shift
        ;;
        --migrate-btcpay)
            MIGRATE_BTCPAY=true
            RUN_CERT_RENEWAL=false
            shift
        ;;
        --renew-certs)
            RUN_CERT_RENEWAL=true
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
export DOMAIN_NAME="$DOMAIN_NAME"
export REGISTRY_DOCKER_IMAGE="registry:2"
export RESTORE_ARCHIVE="$RESTORE_ARCHIVE"
export RESTORE_WWW="$RESTORE_WWW"
export STOP_SERVICES="$STOP_SERVICES"
export BACKUP_CERTS="$BACKUP_CERTS"
export BACKUP_APPS="$BACKUP_APPS"
export RESTORE_BTCPAY="$RESTORE_BTCPAY"
export BACKUP_BTCPAY="$BACKUP_BTCPAY"
export MIGRATE_WWW="$MIGRATE_WWW"
export MIGRATE_BTCPAY="$MIGRATE_BTCPAY"
export RUN_CERT_RENEWAL="$RUN_CERT_RENEWAL"

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
    echo "      Add ssh pubkeys for your various management machines, if any."
    echo "      By default we added your main ssh pubkey: '$SSH_HOME/id_rsa.pub'."
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
        if docker info | grep -q "Swarm: inactive"; then
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


function instantiate_vms {

    export VPS_HOSTING_TARGET="$VPS_HOSTING_TARGET"
    export BTC_CHAIN="$BTC_CHAIN"
    export UPDATE_BTCPAY="$UPDATE_BTCPAY"
    export RECONFIGURE_BTCPAY_SERVER="$RECONFIGURE_BTCPAY_SERVER"

    # iterate over all our server endpoints and provision them if needed.
    # www
    VPS_HOSTNAME=

    for VIRTUAL_MACHINE in www btcpayserver; do
        FQDN=

        export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"

        source "$SITE_PATH/site_definition"
        source ./domain_env.sh

        # VALIDATE THE INPUT from the ENVFILE
        if [ -z "$DOMAIN_NAME" ]; then
            echo "ERROR: DOMAIN_NAME not specified. Use the --domain-name= option."
            exit 1
        fi

        if [ "$VPS_HOSTING_TARGET" = lxd ]; then
            # first let's get the DISK_TO_USE and DATA_PLANE_MACVLAN_INTERFACE from the ss-config
            # which is set up during LXD cluster creation ss-cluster.
            LXD_SS_CONFIG_LINE=
            if lxc network list --format csv | grep lxdbrSS | grep ss-config; then
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

        fi

        export MAC_ADDRESS_TO_PROVISION=
        export VPS_HOSTNAME="$VPS_HOSTNAME"
        export FQDN="$VPS_HOSTNAME.$DOMAIN_NAME"
       
        # ensure the admin has set the MAC address for the base image.
        if [ -z "$SOVEREIGN_STACK_MAC_ADDRESS" ]; then
            echo "ERROR: SOVEREIGN_STACK_MAC_ADDRESS is undefined. Check your project definition."
            exit 1
        fi

        DDNS_HOST=
        MIGRATE_VPS=false
        if [ "$VIRTUAL_MACHINE" = www ]; then
            echo "GOT HERE!!!"
            if [ "$SKIP_WWW" = true ]; then
                continue
            fi

            echo "AND HERE"
            exit 1
            VPS_HOSTNAME="$WWW_HOSTNAME"
            MAC_ADDRESS_TO_PROVISION="$WWW_SERVER_MAC_ADDRESS"
            DDNS_HOST="$WWW_HOSTNAME"
            ROOT_DISK_SIZE_GB="$((ROOT_DISK_SIZE_GB + NEXTCLOUD_SPACE_GB))"
            if [ "$MIGRATE_WWW" = true ]; then
                MIGRATE_VPS=true
            fi
        elif [ "$VIRTUAL_MACHINE" = btcpayserver ] || [ "$SKIP_BTCPAY" = true ]; then
            DDNS_HOST="$BTCPAY_HOSTNAME"
            VPS_HOSTNAME="$BTCPAY_HOSTNAME"
            MAC_ADDRESS_TO_PROVISION="$BTCPAYSERVER_MAC_ADDRESS"
            if [ "$BTC_CHAIN" = mainnet ]; then
                ROOT_DISK_SIZE_GB=150
            elif [ "$BTC_CHAIN" = testnet ]; then
                ROOT_DISK_SIZE_GB=70
            fi

            if [ "$MIGRATE_BTCPAY" = true ]; then
                MIGRATE_VPS=true
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

        # This next section of if statements is our sanity checking area.
        if [ "$VPS_HOSTING_TARGET" = aws ]; then
            # we require DDNS on AWS to set the public DNS to the right host.
            if [ -z "$DDNS_PASSWORD" ]; then
                echo "ERROR: Ensure DDNS_PASSWORD is configured in your site_definition."
                exit 1
            fi
        fi

        MACHINE_EXISTS=false
        if [ "$VPS_HOSTING_TARGET" = aws ] && docker-machine ls -q | grep -q "$FQDN"; then
            MACHINE_EXISTS=true
        fi

        if [ "$VPS_HOSTING_TARGET" = lxd ] && lxc list --format csv | grep -q "$FQDN"; then
            MACHINE_EXISTS=true
        fi

        if [ "$MACHINE_EXISTS"  = true ]; then
            # we delete the machine if the user has directed us to
            if [ "$MIGRATE_VPS" = true ]; then
                
                # if the RESTORE_ARCHIVE is not set, then 
                if [ -z "$RESTORE_ARCHIVE" ]; then
                    RESTORE_ARCHIVE="$LOCAL_BACKUP_PATH/$UNIX_BACKUP_TIMESTAMP.tar.gz"
                fi

                # get a backup of the machine. This is what we restore to the new VPS.
                echo "INFO: Machine exists.  Since we're going to delete it, let's grab a backup. "
                echo "      We don't need to restore services since we're deleting it."
                ./deployment/deploy_vms.sh

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
                fi

                # Then we run the script again to re-instantiate a new VPS, restoring all user data 
                # if restore directory doesn't exist, then we end up with a new site.
                echo "INFO: Recreating the remote VPS then restoring user data."
                sleep 2

                ./deployment/deploy_vms.sh
            else
                ./deployment/deploy_vms.sh
            fi
        else
            if [ "$MIGRATE_VPS" = true ]; then
                echo "INFO: User has indicated to delete the machine, but it doesn't exist."
                echo "      Going to create it anyway."
            fi

            # The machine does not exist. Let's bring it into existence, restoring from latest backup.
            echo "Machine does not exist." 
            ./deployment/deploy_vms.sh
        fi

        # if the local docker client isn't logged in, do so;
        # this helps prevent docker pull errors since they throttle.
        if [ ! -f "$HOME/.docker/config.json" ]; then
            echo "$REGISTRY_PASSWORD" | docker login --username "$REGISTRY_USERNAME" --password-stdin
        fi

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
export SITE_LANGUAGE_CODES="en"
export DUPLICITY_BACKUP_PASSPHRASE="$(new_pass)"
#export BTCPAY_HOSTNAME_IN_CERT="store"
export DEPLOY_GHOST=true
export DEPLOY_NEXTCLOUD=false
export DEPLOY_NOSTR_RELAY=true
export NOSTR_ACCOUNT_PUBKEY="NOSTR_IDENTITY_PUBKEY_GOES_HERE"
export DEPLOY_GITEA=false
#export DEPLOY_ONION_SITE=false
export GHOST_MYSQL_PASSWORD="$(new_pass)"
export GHOST_MYSQL_ROOT_PASSWORD="$(new_pass)"
export NEXTCLOUD_MYSQL_PASSWORD="$(new_pass)"
export NEXTCLOUD_MYSQL_ROOT_PASSWORD="$(new_pass)"
export GITEA_MYSQL_PASSWORD="$(new_pass)"
export GITEA_MYSQL_ROOT_PASSWORD="$(new_pass)"

EOL

            chmod 0744 "$SITE_DEFINITION_PATH"
            echo "INFO: we stubbed a new site_defintion for you at '$SITE_DEFINITION_PATH'. Go update it yo!"
            exit 1

        fi
    fi

}


function stub_project_definition {

    # check to see if the enf file exists. exist if not.
    PROJECT_DEFINITION_PATH="$PROJECT_PATH/project_definition"
    if [ ! -f "$PROJECT_DEFINITION_PATH" ]; then

        # stub out a site_definition with new passwords.
        cat >"$PROJECT_DEFINITION_PATH" <<EOL
#!/bin/bash

# see https://www.sovereign-stack.org/project-definition for more info.

export WWW_SERVER_MAC_ADDRESS="CHANGE_ME_REQUIRED"
export BTCPAYSERVER_MAC_ADDRESS="CHANGE_ME_REQUIRED"
# export BTC_CHAIN=mainnet
export PRIMARY_DOMAIN="CHANGE_ME"
export OTHER_SITES_LIST=""
EOL

        chmod 0744 "$PROJECT_DEFINITION_PATH"
        echo "INFO: we stubbed a new project_defition for you at '$PROJECT_DEFINITION_PATH'. Go update it yo!"
        echo "INFO: Learn more at https://www.sovereign-stack.org/project-definitions/"
        
        exit 1
    fi

    # source project defition.
    source "$PROJECT_DEFINITION_PATH"
}

# let's iterate over the user-supplied domain list and provision each domain.
if [ "$VPS_HOSTING_TARGET" = lxd ]; then

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

    # stub out the project definition if needed.
    stub_project_definition
    
    # the DOMAIN_LIST is a complete list of all our domains. We often iterate over this list.
    export DOMAIN_LIST="${PRIMARY_DOMAIN},${OTHER_SITES_LIST}"
    export DOMAIN_COUNT=$(("$(echo $DOMAIN_LIST | tr -cd , | wc -c)"+1))

    # let's provision our primary domain first.
    export DOMAIN_NAME="$PRIMARY_DOMAIN"
    export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"
    export PRIMARY_WWW_FQDN="$WWW_HOSTNAME.$DOMAIN_NAME"
    
    stub_site_definition
    
    # bring the vms up under the primary domain name.
    instantiate_vms

    # let's stub out the rest of our site definitions, if any.
    for DOMAIN_NAME in ${OTHER_SITES_LIST//,/ }; do
        export DOMAIN_NAME="$DOMAIN_NAME"
        export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"

        # stub out the site_defition if it's doesn't exist.
        stub_site_definition
    done

    # now let's run the www and btcpay-specific provisioning scripts.
    bash -c "./deployment/www/go.sh"
    bash -c "./deployment/btcpayserver/go.sh"

elif [ "$VPS_HOSTING_TARGET" = aws ]; then
    stub_site_definition

    # if we're on AWS, we can just provision each system separately.
    run_domain
fi