#!/bin/bash

# https://www.sovereign-stack.org/ss-down/

set -eu
cd "$(dirname "$0")"

if lxc remote get-default -q | grep -q "local"; then
    echo "ERROR: you are on the local lxc remote. Nothing to take down"
    exit 1
fi

SERVER_TO_STOP=
OTHER_SITES_LIST=

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --server=*)
            SERVER_TO_STOP="${i#*=}"
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

if [ -z "$SERVER_TO_STOP" ]; then
    echo "ERROR: you MUST specify a server to stop with '--server=www' for example."
    exit 1
fi


. ./deployment_defaults.sh

. ./remote_env.sh

. ./project_env.sh

# let's bring down services on the remote deployment if necessary.
export DOMAIN_NAME="$PRIMARY_DOMAIN"
export SITE_PATH="$SITES_PATH/$PRIMARY_DOMAIN"

source "$SITE_PATH/site.conf"
source ./project/domain_env.sh

source ./domain_list.sh

if [ "$SERVER_TO_STOP" = www ]; then
    DOCKER_HOST="ssh://ubuntu@$PRIMARY_WWW_FQDN" ./project/www/stop_docker_stacks.sh
fi

if [ "$SERVER_TO_STOP" = btcpayserver ]; then
    if wait-for-it -t 5 "$BTCPAY_SERVER_FQDN":22; then
        ssh "$BTCPAY_SERVER_FQDN" "bash -c $BTCPAY_SERVER_APPPATH/btcpay-down.sh"
    else
        echo "ERROR: the remote BTCPAY Server is not available on ssh."
        exit 1
    fi
fi

if [ "$SERVER_TO_STOP" = clamsserver ]; then
    DOCKER_HOST="ssh://ubuntu@$CLAMS_SERVER_FQDN" ./project/clams-server/down.sh
fi