#!/bin/bash


# the DOMAIN_LIST is a complete list of all our domains. We often iterate over this list.
DOMAIN_LIST="${PRIMARY_DOMAIN}"
if [ -n "$OTHER_SITES_LIST" ]; then
    DOMAIN_LIST="${DOMAIN_LIST},${OTHER_SITES_LIST}"
fi

export DOMAIN_LIST="$DOMAIN_LIST"
export DOMAIN_COUNT=$(("$(echo "$DOMAIN_LIST" | tr -cd , | wc -c)"+1))
export OTHER_SITES_LIST="$OTHER_SITES_LIST"

export PRIMARY_WWW_FQDN="$WWW_HOSTNAME.$DOMAIN_NAME"
export BTCPAY_SERVER_FQDN="$BTCPAY_SERVER_HOSTNAME.$DOMAIN_NAME"
export LNPLAY_SERVER_FQDN="$LNPLAY_SERVER_HOSTNAME.$DOMAIN_NAME"