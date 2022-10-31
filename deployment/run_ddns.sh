#!/bin/bash

set -eu

DDNS_STRING=

# for the www stack, we register only the domain name so our URLs look like https://$DOMAIN_NAME
if [ "$VIRTUAL_MACHINE" = www ] || [ "$VIRTUAL_MACHINE" = certonly ]; then
    DDNS_STRING="@"
else
    DDNS_STRING="$DDNS_HOST"
fi

# wait for DNS to get setup. Pass in the IP address of the actual VPS.
MACHINE_IP="$(docker-machine ip "$FQDN")"
DDNS_SLEEP_SECONDS=60
while true; do
    # we test the www CNAME here so we can be assured the underlying has corrected.
    if [[ "$(getent hosts "$FQDN" | awk '{ print $1 }')" == "$MACHINE_IP" ]]; then
        echo ""
        echo "SUCCESS: The DNS appears to be configured correctly."

        echo "INFO: Waiting $DDNS_SLEEP_SECONDS seconds to allow cached DNS records to expire."
        sleep "$DDNS_SLEEP_SECONDS";
        break;
    fi

    printf "." && sleep 2;
done
