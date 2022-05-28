#!/bin/bash

set -eux
cd "$(dirname "$0")"

# let's make sure we have an ssh keypair. We just use ~/.ssh/id_rsa
if [ ! -f "$SSH_HOME/id_rsa" ]; then
    # generate a new SSH key for the base vm image.
    ssh-keygen -f "$SSH_HOME/id_rsa" -t ecdsa -b 521 -N ""
fi

## This is a weird if clause since we need to LEFT-ALIGN the statement below.
SSH_STRING="Host ${FQDN}"
if ! grep -q "$SSH_STRING" "$SSH_HOME/config"; then

########## BEGIN
cat >> "$SSH_HOME/config" <<-EOF

${SSH_STRING}
    HostName ${FQDN}
    User ubuntu
EOF
###

fi

# when set to true, this flag indicates that a new VPS was created during THIS script run.
if [ "$VPS_HOSTING_TARGET" = aws ]; then
    # let's create the remote VPS if needed.
    if ! docker-machine ls -q --filter name="$FQDN" | grep -q "$FQDN"; then
        RUN_BACKUP=false

        ./provision_vps.sh

        ./prepare_vps_host.sh
    fi
elif [ "$VPS_HOSTING_TARGET" = lxd ]; then
    ssh-keygen -f "$SSH_HOME/known_hosts" -R "$FQDN"

    # if the machine doesn't exist, we create it.
    if ! lxc list --format csv | grep -q "$LXD_VM_NAME"; then
        export RUN_BACKUP=false

        # create a base image if needed and instantiate a VM.
        if [ -z "$MAC_ADDRESS_TO_PROVISION" ]; then
            echo "ERROR: You MUST define a MAC Address for all your machines by setting WWW_MAC_ADDRESS, BTCPAY_MAC_ADDRESS, UMBREL_MAC_ADDRESS, in your site defintion."
            echo "INFO: IMPORTANT! You MUST have DHCP Reservations for these MAC addresses. You also need static DNS entries."
            exit 1
        fi

        ./provision_lxc.sh
    fi

    # prepare the VPS to support our applications and backups and stuff.
    ./prepare_vps_host.sh
fi

# if the local docker client isn't logged in, do so;
# this helps prevent docker pull errors since they throttle.
if [ ! -f "$HOME/.docker/config.json" ]; then
    echo "$REGISTRY_PASSWORD" | docker login --username "$REGISTRY_USERNAME" --password-stdin
fi

# this tells our local docker client to target the remote endpoint via SSH
export DOCKER_HOST="ssh://ubuntu@$FQDN"    


# the following scripts take responsibility for the rest of the provisioning depending on the app you're deploying.
if [ "$APP_TO_DEPLOY" = www ]; then
    ./go_www.sh
elif [ "$APP_TO_DEPLOY" = btcpay ]; then
    ./go_btcpay.sh
elif [ "$APP_TO_DEPLOY" = umbrel ]; then
    ./go_umbrel.sh
elif [ "$APP_TO_DEPLOY" = certonly ]; then
    # renew the certs; certbot takes care of seeing if we need to actually renew.
    if [ "$RUN_CERT_RENEWAL" = true ]; then
        ./generate_certs.sh
    fi
    
    echo "INFO: Please run 'docker-machine rm -f $FQDN' to remove the remote VPS."
    exit
else
    echo "ERROR: APP_TO_DEPLOY not set correctly. Please refer to the documentation for allowable values."
    exit
fi

echo "Successfull deployed '$DOMAIN_NAME' with git commit '$(cat ./.git/refs/heads/master)' VPS_HOSTING_TARGET=$VPS_HOSTING_TARGET;" >> "$SITE_PATH/debug.log"
