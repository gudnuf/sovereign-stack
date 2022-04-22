#!/bin/bash

set -eux
cd "$(dirname "$0")"

if [ ! -f "$HOME/.aws/credentials" ]; then

    # TODO write a credential file baseline
    echo "ERROR: Please update your '$HOME/.aws/credentials' file before continuing."
    mkdir -p "$HOME/.aws"
    touch "$HOME/.aws/credentials"

    # stub out a site_definition with new passwords.
    cat >"$HOME/.aws/credentials" <<EOL
#!/bin/bash

# enter your AWS Access Key and Secret Access Key here.
export AWS_ACCESS_KEY=
export AWS_SECRET_ACCESS_KEY=

EOL

    exit 1
fi

source "$HOME/.aws/credentials"

if [ -z "$AWS_ACCESS_KEY" ]; then
    echo "ERROR: AWS_ACCESS_KEY is not set."
    exit 1
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "ERROR: AWS_SECRET_ACCESS_KEY is not set."
    exit 1
fi

# ports: All ports go to nginx; 8448 directs to the matrix federation servoce.

# Note, we assume the script has already made sure the machine doesn't exist.
if [ "$APP_TO_DEPLOY" = www ] || [ "$APP_TO_DEPLOY" = certonly ]; then
    # creates a public VM in AWS and provisions the bcm website.
    docker-machine create --driver amazonec2 \
        --amazonec2-open-port 80 \
        --amazonec2-open-port 443 \
        --amazonec2-open-port 8448 \
        --amazonec2-access-key "$AWS_ACCESS_KEY" \
        --amazonec2-secret-key "$AWS_SECRET_ACCESS_KEY" \
        --amazonec2-region "$AWS_REGION" \
        --amazonec2-ami "$AWS_AMI_ID" \
        --amazonec2-root-size "$ROOT_DISK_SIZE_GB" \
        --amazonec2-instance-type "$WWW_INSTANCE_TYPE" \
        --engine-label tag="$LATEST_GIT_TAG" \
        --engine-label commit="$LATEST_GIT_COMMIT" \
        "$FQDN"
        
elif [ "$APP_TO_DEPLOY" = btcpay ]; then
    # creates a public VM in AWS and provisions the bcm website.
    docker-machine create --driver amazonec2 \
        --amazonec2-open-port 80 \
        --amazonec2-open-port 443 \
        --amazonec2-open-port 9735 \
        --amazonec2-access-key "$AWS_ACCESS_KEY" \
        --amazonec2-secret-key "$AWS_SECRET_ACCESS_KEY" \
        --amazonec2-region "$AWS_REGION" \
        --amazonec2-ami "$AWS_AMI_ID" \
        --amazonec2-root-size "$ROOT_DISK_SIZE_GB" \
        --amazonec2-instance-type "$BTCPAY_INSTANCE_TYPE" \
        --engine-label tag="$LATEST_GIT_TAG" \
        --engine-label commit="$LATEST_GIT_COMMIT" \
        "$FQDN"

fi

docker-machine scp "$SITE_PATH/authorized_keys" "$FQDN:$REMOTE_HOME/authorized_keys"
docker-machine ssh "$FQDN" "cat $REMOTE_HOME/authorized_keys >> $REMOTE_HOME/.ssh/authorized_keys"

# we have to ensure ubuntu is able to do sudo less docker commands.
docker-machine ssh "$FQDN" sudo usermod -aG docker ubuntu

# we restart so dockerd starts with fresh group membership.
docker-machine ssh "$FQDN" sudo systemctl restart docker

# TODO INSTALL DOCKER COMPOSE

# let's wire up the DNS so subsequent ssh commands resolve to the VPS.
./run_ddns.sh

# remove the SSH hostname from known_hosts as we'll
# todo why do we need this again?
ssh-keygen -f "$SSH_HOME/known_hosts" -R "$FQDN"
