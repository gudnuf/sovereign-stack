#!/bin/bash

set -eu

# create the ddclient.conf file
cat >/tmp/ddclient.conf <<EOL
### ddclient.conf
### namecheap
##################
use=web, web=checkip.dyndns.com/, web-skip='IP Address'
protocol=namecheap
server=dynamicdns.park-your-domain.com
login=${DOMAIN_NAME}
password=${DDNS_PASSWORD}
EOL

# for the www stack, we register only the domain name so our URLs look like https://$DOMAIN_NAME
if [ "$APP_TO_DEPLOY" = www ] || [ "$APP_TO_DEPLOY" = certonly ]; then
    DDNS_STRING="@"
else
    DDNS_STRING="$DDNS_HOST"
fi

# append the correct DDNS string to ddclient.conf
echo "$DDNS_STRING" >> /tmp/ddclient.conf

cat /tmp/ddclient.conf

# send the ddclient.conf file to the remote vps.
docker-machine scp /tmp/ddclient.conf "$FQDN:$REMOTE_HOME/ddclient.conf"
docker-machine ssh "$FQDN" sudo cp "$REMOTE_HOME/ddclient.conf" /etc/ddclient.conf
docker-machine ssh "$FQDN" sudo chown root:root /etc/ddclient.conf
docker-machine ssh "$FQDN" sudo chmod 0600 /etc/ddclient.conf
docker-machine ssh "$FQDN" sudo apt-get -qq install -y ddclient wait-for-it git rsync duplicity sshfs
docker-machine ssh "$FQDN" sudo ddclient

# wait for DNS to get setup. Pass in the IP address of the actual VPS.
echo "INFO: Verifying correct DNS configuration. This may take a while."
MACHINE_IP="$(docker-machine ip "$FQDN")"

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
