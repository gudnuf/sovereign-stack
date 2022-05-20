#!/bin/bash

set -eux
cd "$(dirname "$0")"

# let's make sure we have an ssh keypair. We just use ~/.ssh/id_rsa
if [ ! -f "$SSH_HOME/id_rsa" ]; then
    # generate a new SSH key for the base vm image.
    ssh-keygen -f "$SSH_HOME/id_rsa" -t ecdsa -b 521 -N ""
fi

# if an authorized_keys file does not exist, we'll stub one out with the current user.
# add additional id_rsa.pub entries manually for more administrative logins.
if [ ! -f "$SITE_PATH/authorized_keys" ]; then
    cat "$SSH_HOME/id_rsa.pub" >> "$SITE_PATH/authorized_keys"
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

    #check to ensure the MACVLAN interface has been set by the user
    if [ -z "$MACVLAN_INTERFACE" ]; then
        echo "ERROR: MACVLAN_INTERFACE has not been defined. Use '--macvlan-interface=eno1' for example."
        exit 1
    fi

    # let's first check to ensure there's a cert.tar.gz. We need a valid cert for testing.
    if [ ! -f "$SITE_PATH/certs.tar.gz" ]; then
        echo "ERROR: We need a valid cert for testing."
        exit 1
    fi

    # if the machine doesn't exist, we create it.
    if ! lxc list --format csv | grep -q "$LXD_VM_NAME"; then
        export RUN_BACKUP=false

        # create a base image if needed and instantiate a VM.
        if [ -z "$MAC_ADDRESS_TO_PROVISION" ]; then
            echo "ERROR: You MUST define a MAC Address for all your machines."
            exit 1
        fi

        ./provision_lxc.sh
    fi

    # prepare the VPS to support our applications and backups and stuff.
    ./prepare_vps_host.sh
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

echo "Successfull deployed '$DOMAIN_NAME' with git commit '$(cat ./.git/refs/heads/master)' VPS_HOSTING_TARGET=$VPS_HOSTING_TARGET; Latest git tag is $LATEST_GIT_TAG" >> "$SITE_PATH/debug.log"
