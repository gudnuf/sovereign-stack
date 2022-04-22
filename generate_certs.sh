#!/bin/bash

set -exu
cd "$(dirname "$0")"


if [ "$VPS_HOSTING_TARGET" = aws ]; then
    # let's do a refresh of the certificates. Let's Encrypt will not run if it's not time.
    docker pull certbot/certbot

    docker run -it --rm \
        --name certbot \
        -p 80:80 \
        -p 443:443 \
        -v /etc/letsencrypt:/etc/letsencrypt \
        -v /var/lib/letsencrypt:/var/lib/letsencrypt certbot/certbot \
        certonly -v --noninteractive --agree-tos --key-type ecdsa --standalone --expand -d "$DOMAIN_NAME" -d "$FQDN" -d "$NEXTCLOUD_FQDN" -d "$MATRIX_FQDN" -d "$GITEA_FQDN" --email "$CERTIFICATE_EMAIL_ADDRESS"

    # backup the certs to our SITE_PATH/certs.tar.gz so we have them handy (for local development)
    ssh "$FQDN" sudo tar -zcvf "$REMOTE_HOME/certs.tar.gz" -C /etc ./letsencrypt
    ssh "$FQDN" sudo chown ubuntu:ubuntu "$REMOTE_HOME/certs.tar.gz"

    # now pull the tarballs down the local machine.
    scp "$FQDN:$REMOTE_HOME/certs.tar.gz" "$SITE_PATH/certs.tar.gz"
else
    echo "INFO: Skipping certificate renewal since we're on hosting provider=lxd."
fi