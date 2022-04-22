#!/bin/bash

set -eux

DDNS_STRING=

# for the www stack, we register only the domain name so our URLs look like https://$DOMAIN_NAME
if [ "$APP_TO_DEPLOY" = www ] || [ "$APP_TO_DEPLOY" = certonly ]; then
    DDNS_STRING="@"
else
    DDNS_STRING="$DDNS_HOST"
fi

# wait for DNS to get setup. Pass in the IP address of the actual VPS.
MACHINE_IP="$(docker-machine ip "$FQDN")"
if [ "$VPS_HOSTING_TARGET" = aws ]; then

    # wire DNS entries using namecheap DDNS API (via HTTPS rather than ddclient)
    curl "https://dynamicdns.park-your-domain.com/update?host=$DDNS_STRING&domain=$DOMAIN_NAME&password=$DDNS_PASSWORD&ip=$MACHINE_IP"

    #install dependencies.
    docker-machine ssh "$FQDN" sudo apt-get -qq install -y wait-for-it git rsync duplicity sshfs
fi

DDNS_SLEEP_SECONDS=60
while true; do
    # we test the www CNAME here so we can be assured the underlying has corrected.
    if [[ "$(getent hosts "$FQDN" | awk '{ print $1 }')" == "$MACHINE_IP" ]]; then
        echo ""
        echo "SUCCESS: The DNS appears to be configured correctly."

        echo "INFO: Waiting $DDNS_SLEEP_SECONDS seconds to allow stale DNS records to expire."
        sleep "$DDNS_SLEEP_SECONDS";
        break;
    fi

    printf "." && sleep 2;
done
