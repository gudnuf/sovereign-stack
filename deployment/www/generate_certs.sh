#!/bin/bash

set -e


# let's do a refresh of the certificates. Let's Encrypt will not run if it's not time.
docker pull certbot/certbot:latest

# when deploying to AWS, www exists on a separate IP address from btcpay, etc.
# thus, we structure the certificate accordingly.
if [ "$VPS_HOSTING_TARGET" = aws ]; then
    docker run -it --rm \
        --name certbot \
        -p 80:80 \
        -p 443:443 \
        -v "$REMOTE_HOME/letsencrypt":/etc/letsencrypt \
        -v /var/lib/letsencrypt:/var/lib/letsencrypt \
        -v "$REMOTE_HOME/letsencrypt_logs":/var/log/letsencrypt \
        certbot/certbot certonly -v --noninteractive --agree-tos --key-type ecdsa --standalone --expand -d "$DOMAIN_NAME" -d "$FQDN" -d "$NEXTCLOUD_FQDN" -d "$GITEA_FQDN" --email "$CERTIFICATE_EMAIL_ADDRESS"

elif [ "$VPS_HOSTING_TARGET" = lxd ]; then
    # with the lxd side, we are trying to expose ALL OUR services from one IP address, which terminates
    # at a cachehing reverse proxy that runs nginx.
    # docker run -it --rm \
    #     --name certbot \
    #     -p 80:80 \
    #     -p 443:443 \
    #     -v "$REMOTE_HOME/letsencrypt":/etc/letsencrypt \
    #     -v /var/lib/letsencrypt:/var/lib/letsencrypt \
    #     -v "$REMOTE_HOME/letsencrypt_logs":/var/log/letsencrypt \
    #     certbot/certbot certonly -v --noninteractive --agree-tos --key-type ecdsa --standalone --expand -d "$DOMAIN_NAME" -d "$PRIMARY_WWW_FQDN" -d "$BTCPAY_USER_FQDN" -d "$NEXTCLOUD_FQDN" -d "$GITEA_FQDN" -d "$NOSTR_FQDN" --email "$CERTIFICATE_EMAIL_ADDRESS"


    for DOMAIN_NAME in ${DOMAIN_LIST//,/ }; do
        export DOMAIN_NAME="$DOMAIN_NAME"
        export SITE_PATH="$SITES_PATH/$DOMAIN_NAME"
    
        # source the site path so we know what features it has.
        source ../../reset_env.sh
        source "$SITE_PATH/site_definition"
        source ../../domain_env.sh

        # with the lxd side, we are trying to expose ALL OUR services from one IP address, which terminates
        # at a cachehing reverse proxy that runs nginx.

        ssh "$PRIMARY_WWW_FQDN" sudo mkdir -p "$REMOTE_HOME/letsencrypt/$DOMAIN_NAME/_logs"

        docker run -it --rm \
            --name certbot \
            -p 80:80 \
            -p 443:443 \
            -v "$REMOTE_HOME/letsencrypt/$DOMAIN_NAME":/etc/letsencrypt \
            -v /var/lib/letsencrypt:/var/lib/letsencrypt \
            -v "$REMOTE_HOME/letsencrypt/$DOMAIN_NAME/_logs":/var/log/letsencrypt \
            certbot/certbot certonly -v --noninteractive --agree-tos --key-type ecdsa --standalone --expand -d "$DOMAIN_NAME" -d "$WWW_FQDN" -d "$BTCPAY_USER_FQDN" -d "$NEXTCLOUD_FQDN" -d "$GITEA_FQDN" -d "$NOSTR_FQDN" --email "$CERTIFICATE_EMAIL_ADDRESS"

        sleep 3
    done
fi
