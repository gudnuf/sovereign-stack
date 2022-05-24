#!/bin/bash

set -e

# let's do a refresh of the certificates. Let's Encrypt will not run if it's not time.
docker pull certbot/certbot:latest

# when deploying to AWS, www exists on a separate IP address from btcpay, umbrel, etc.
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
    docker run -it --rm \
        --name certbot \
        -p 80:80 \
        -p 443:443 \
        -v "$REMOTE_HOME/letsencrypt":/etc/letsencrypt \
        -v /var/lib/letsencrypt:/var/lib/letsencrypt \
        -v "$REMOTE_HOME/letsencrypt_logs":/var/log/letsencrypt \
        certbot/certbot certonly -v --noninteractive --agree-tos --key-type ecdsa --standalone --expand -d "$DOMAIN_NAME" -d "$FQDN" -d "$NEXTCLOUD_FQDN" -d "$GITEA_FQDN" -d "$BTCPAY_FQDN" -d "$NOSTR_FQDN" --email "$CERTIFICATE_EMAIL_ADDRESS"

fi
