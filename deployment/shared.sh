#!/bin/bash

set -eu

# check to see if the enf file exists. exist if not.
if [ ! -d "$SITE_PATH" ]; then
    echo "ERROR: '$SITE_PATH' does not exist."
    exit 1
fi

function new_pass {
    apg -a 1 -M nc -n 3 -m 26 -E GHIJKLMNOPQRSTUVWXYZ | head -n1 | awk '{print $1;}'
} 

# check to see if the enf file exists. exist if not.
SITE_DEFINITION_PATH="$SITE_PATH/site_definition"
if [ ! -f "$SITE_DEFINITION_PATH" ]; then
    echo "WARNING: '$SITE_DEFINITION_PATH' does not exist! We have stubbed one out for you, but you need to UPDATE IT!"

    # stub out a site_definition with new passwords.
    cat >"$SITE_DEFINITION_PATH" <<EOL
#!/bin/bash

export SITE_TITLE="Short Title of Project"
export DOMAIN_NAME="domain.tld"
export DDNS_PASSWORD=
export SMTP_PASSWORD=

# TODO VERIFY SECURE RNG
export GHOST_MYSQL_PASSWORD="$(new_pass)"
export GHOST_MYSQL_ROOT_PASSWORD="$(new_pass)"
export NEXTCLOUD_MYSQL_PASSWORD="$(new_pass)"
export GITEA_MYSQL_PASSWORD="$(new_pass)"
export NEXTCLOUD_MYSQL_ROOT_PASSWORD="$(new_pass)"
#export GITEA_MYSQL_ROOT_PASSWORD="$(new_pass)"
export DUPLICITY_BACKUP_PASSPHRASE="$(new_pass)"
#export DEPLOY_WWW_SERVER=false
#export DEPLOY_BTCPAY_SERVER=false
#export DEPLOY_UMBREL_VPS=false
export DEPLOY_GHOST=true
export DEPLOY_NOSTR=false
export DEPLOY_NEXTCLOUD=true
export DEPLOY_ONION_SITE=false
export NOSTR_ACCOUNT_PUBKEY="CHANGE_ME"

# valid options: 'regtest' and 'mainnet'
#export BTC_CHAIN=regtest
#export WWW_INSTANCE_TYPE="t2.medium"
#export BTCPAY_ADDITIONAL_HOSTNAMES="pay.domain.tld"

EOL

    chmod 0744 "$SITE_DEFINITION_PATH"
    exit 1

fi

DOCKER_YAML_PATH="$SITE_PATH/appstack.yml"
export DOCKER_YAML_PATH="$DOCKER_YAML_PATH"

# TODO add file existence check
if [ ! -f "$SITE_PATH/site_definition" ]; then
    echo "ERROR: site_definition does not exist."
    exit 1
fi
# shellcheck disable=SC1090
source "$SITE_PATH/site_definition"

export REMOTE_HOME="/home/ubuntu"
BACKUP_TIMESTAMP="$(date +"%Y-%m")"
UNIX_BACKUP_TIMESTAMP="$(date +%s)"
export BACKUP_TIMESTAMP="$BACKUP_TIMESTAMP"
export UNIX_BACKUP_TIMESTAMP="$UNIX_BACKUP_TIMESTAMP"
REMOTE_BACKUP_PATH="$REMOTE_HOME/backups/$APP_TO_DEPLOY/$BACKUP_TIMESTAMP"
LOCAL_BACKUP_PATH="$SITE_PATH/backups/$APP_TO_DEPLOY/$BACKUP_TIMESTAMP"
export LOCAL_BACKUP_PATH="$LOCAL_BACKUP_PATH"
BACKUP_PATH_CREATED=false
if [ ! -d "$LOCAL_BACKUP_PATH" ]; then
    mkdir -p "$LOCAL_BACKUP_PATH"
    BACKUP_PATH_CREATED=true
fi

export BACKUP_PATH_CREATED="$BACKUP_PATH_CREATED"
mkdir -p "$SSHFS_PATH"

# VALIDATE THE INPUT from the ENVFILE
if [ -z "$DOMAIN_NAME" ]; then
    echo "ERROR: DOMAIN_NAME not specified. Use the --domain-name= option."
    exit 1
fi

# TODO, ensure VPS_HOSTING_TARGET is in range.
export NEXTCLOUD_FQDN="$NEXTCLOUD_HOSTNAME.$DOMAIN_NAME"
export GITEA_FQDN="$GITEA_HOSTNAME.$DOMAIN_NAME"
export NOSTR_FQDN="$NOSTR_HOSTNAME.$DOMAIN_NAME"

export ADMIN_ACCOUNT_USERNAME="info"
export CERTIFICATE_EMAIL_ADDRESS="$ADMIN_ACCOUNT_USERNAME@$DOMAIN_NAME"
export MAIL_FROM="$SITE_TITLE <$CERTIFICATE_EMAIL_ADDRESS>"
export REMOTE_CERT_BASE_DIR="$REMOTE_HOME/.certs"
export REMOTE_CERT_DIR="$REMOTE_CERT_BASE_DIR/$FQDN"

touch "$SITE_PATH/debug.log"
export SMTP_LOGIN="www@mail.$DOMAIN_NAME"
export VM_NAME="sovereign-stack-base"
export REMOTE_NEXTCLOUD_PATH="$REMOTE_HOME/nextcloud"
export REMOTE_GITEA_PATH="$REMOTE_HOME/gitea"

# this space is for OS, docker images, etc. DOES NOT INCLUDE USER DATA.
export ROOT_DISK_SIZE_GB=20

DDNS_HOST=
if [ "$APP_TO_DEPLOY" = www ]; then
    DDNS_HOST="$WWW_HOSTNAME"
    ROOT_DISK_SIZE_GB=$((ROOT_DISK_SIZE_GB + NEXTCLOUD_SPACE_GB))
elif [ "$APP_TO_DEPLOY" = btcpay ]; then
    DDNS_HOST="$BTCPAY_HOSTNAME"
    if [ "$BTC_CHAIN" = mainnet ]; then
        ROOT_DISK_SIZE_GB=150
    elif [ "$BTC_CHAIN" = testnet ]; then
        ROOT_DISK_SIZE_GB=40
    fi
elif [ "$APP_TO_DEPLOY" = umbrel ]; then
    DDNS_HOST="$UMBREL_HOSTNAME"
    if [ "$BTC_CHAIN" = mainnet ]; then
        ROOT_DISK_SIZE_GB=1000
    elif [ "$BTC_CHAIN" = testnet ]; then
        ROOT_DISK_SIZE_GB=70
    fi
elif [ "$APP_TO_DEPLOY" = certonly ]; then
    DDNS_HOST="$WWW_HOSTNAME"
    ROOT_DISK_SIZE_GB=8
else
    echo "ERROR: APP_TO_DEPLOY not within allowable bounds."
    exit
fi

# we use this in other subshells.
export APP_TO_DEPLOY="$APP_TO_DEPLOY"
export DDNS_HOST="$DDNS_HOST"
export FQDN="$DDNS_HOST.$DOMAIN_NAME"
export LXD_VM_NAME="${FQDN//./-}"
export BTC_CHAIN="$BTC_CHAIN"
export ROOT_DISK_SIZE_GB=$ROOT_DISK_SIZE_GB
export WWW_INSTANCE_TYPE="$WWW_INSTANCE_TYPE"
export REMOTE_BACKUP_PATH="$REMOTE_BACKUP_PATH"
export BTCPAY_ADDITIONAL_HOSTNAMES="$BTCPAY_ADDITIONAL_HOSTNAMES"

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

if [ -z "$SMTP_PASSWORD" ]; then
    echo "ERROR: Ensure SMTP_PASSWORD is configured in your site_definition."
    exit 1
fi

if [ -z "$DDNS_PASSWORD" ]; then
    echo "ERROR: Ensure DDNS_PASSWORD is configured in your site_definition."
    exit 1
fi

if [ -z "$DOMAIN_NAME" ]; then
    echo "ERROR: Ensure DOMAIN_NAME is configured in your site_definition."
    exit 1
fi

if [ -z "$SITE_TITLE" ]; then
    echo "ERROR: Ensure SITE_TITLE is configured in your site_definition."
    exit 1
fi

if [ -z "$DEPLOY_BTCPPAY_SERVER" ]; then
    echo "ERROR: Ensure DEPLOY_BTCPPAY_SERVER is configured in your site_definition."
    exit 1
fi


if [ -z "$DEPLOY_UMBREL_VPS" ]; then
    echo "ERROR: Ensure DEPLOY_UMBREL_VPS is configured in your site_definition."
    exit 1
fi

if [ -z "$NOSTR_ACCOUNT_PUBKEY" ]; then 
    echo "ERROR: You MUST specify a Nostr public key. This is how you get all your social features."
    echo "INFO: Go to your site_definition file and set the NOSTR_ACCOUNT_PUBKEY variable."
    exit 1
fi

