#!/bin/bash

set -eux
cd "$(dirname "$0")"

./stub_lxc_profile.sh "$LXD_VM_NAME"

function run_ddns {
    # now that the VM has an IP, we can update the DNS record. TODO add additional DNS providers here; namecheap only atm.
    DDNS_STRING="$VPS_HOSTNAME"
    if [ "$VPS_HOSTNAME" = www ]; then
        # next update our DDNS record. TODO enable local/remote name provider. 
        DDNS_STRING="@"
    fi

    # if the DNS record is incorrect, we run DDNS to get it corrected yo.
    if "$(getent hosts "$FQDN" | awk '{ print $1 }')" != "$IP_V4_ADDRESS"; then
        curl "https://dynamicdns.park-your-domain.com/update?host=$DDNS_STRING&domain=$DOMAIN_NAME&password=$DDNS_PASSWORD&ip=$IP_V4_ADDRESS"

        DDNS_SLEEP_SECONDS=60
        while true; do
            # we test the www CNAME here so we can be assured the underlying has corrected.
            if [[ "$(getent hosts "$FQDN" | awk '{ print $1 }')" == "$IP_V4_ADDRESS" ]]; then
                echo ""
                echo "SUCCESS: The DNS appears to be configured correctly."

                # we're waiting here to allow dns records to stale out.
                # this is necessary for certificate renewal; letsencrypt might have stale records
                # and cert renew won't succeed. HOWEVER, if we're running a restore operation, we SHOULD NOT
                # do a certificate renewal (we're restoring old certs). Thus it is not necessary to sleep here.
                if [ "$RUN_RESTORE" = false ]; then
                    echo "INFO: Waiting $DDNS_SLEEP_SECONDS seconds to allow cached DNS records to expire."
                    sleep "$DDNS_SLEEP_SECONDS";
                fi
                
                break;
            fi

            printf "." && sleep 2;
        done
    fi

}

# now let's create a new VM to work with.
lxc init --profile="$LXD_VM_NAME" "$VM_NAME" "$LXD_VM_NAME" --vm

# let's PIN the HW address for now so we don't exhaust IP
# and so we can set DNS internally.
lxc config set "$LXD_VM_NAME" "volatile.enp5s0.hwaddr=$MAC_ADDRESS_TO_PROVISION"
lxc config device override "$LXD_VM_NAME" root size="${ROOT_DISK_SIZE_GB}GB"

lxc start "$LXD_VM_NAME"

./wait_for_lxc_ip.sh "$LXD_VM_NAME"

if [ "$VPS_HOSTING_TARGET" = aws ]; then
    run_ddns

    # remove any existing SSH identities for the host, then add it back.
    ssh-keygen -R "$IP_V4_ADDRESS"

fi
