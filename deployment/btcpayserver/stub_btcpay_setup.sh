#!/bin/bash

set -e
cd "$(dirname "$0")"

# export BTCPAY_FASTSYNC_ARCHIVE_FILENAME="utxo-snapshot-bitcoin-testnet-1445586.tar"
# BTCPAY_REMOTE_RESTORE_PATH="/var/lib/docker/volumes/generated_bitcoin_datadir/_data"

# This is the config for a basic proxy to the listening port 127.0.0.1:2368
# It also supports modern TLS, so SSL certs must be available.
#opt-add-nostr-relay;
cat > "$SITE_PATH/btcpay.sh" <<EOL
#!/bin/bash

set -e
cd "\$(dirname "\$0")"

# wait for cloud-init to complete yo
while [ ! -f /var/lib/cloud/instance/boot-finished ]; do
    sleep 1
done

if [ ! -d "btcpayserver-docker" ]; then 
    echo "cloning btcpayserver-docker"; 
    git clone -b master https://github.com/btcpayserver/btcpayserver-docker btcpayserver-docker;
    git config --global --add safe.directory /home/ubuntu/btcpayserver-docker
else
    cd ./btcpayserver-docker
    git pull
    git pull --all --tags
    cd -
fi

cd btcpayserver-docker

export BTCPAY_HOST="${BTCPAY_USER_FQDN}"
export BTCPAY_ANNOUNCEABLE_HOST="${DOMAIN_NAME}"
export NBITCOIN_NETWORK="${BTC_CHAIN}"
export LIGHTNING_ALIAS="${PRIMARY_DOMAIN}"
export BTCPAYGEN_LIGHTNING="clightning"
export BTCPAYGEN_CRYPTO1="btc"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-save-storage-s;opt-add-btctransmuter;bitcoin-clightning.custom;"
export BTCPAYGEN_REVERSEPROXY="nginx"
export BTCPAY_ENABLE_SSH=false
export BTCPAY_BASE_DIRECTORY=${REMOTE_HOME}
export BTCPAYGEN_EXCLUDE_FRAGMENTS="nginx-https;"
export REVERSEPROXY_DEFAULT_HOST="$BTCPAY_USER_FQDN"

if [ "\$NBITCOIN_NETWORK" != regtest ]; then
    # run fast_sync if it's not been done before.
    if [ ! -f /home/ubuntu/fast_sync_completed ]; then
        cd ./contrib/FastSync
        ./load-utxo-set.sh
        touch /home/ubuntu/fast_sync_completed
        cd -
    fi
fi


# next we create fragments to customize various aspects of the system
# this block customizes clightning to ensure the correct endpoints are being advertised
# We want to advertise the correct ipv4 endpoint for remote hosts to get in touch.
cat > ${REMOTE_HOME}/btcpayserver-docker/docker-compose-generator/docker-fragments/bitcoin-clightning.custom.yml <<EOF

services:
  clightning_bitcoin:
    environment:
      LIGHTNINGD_OPT: |
        announce-addr-dns=true

EOF

# run the setup script.
. ./btcpay-setup.sh -i

touch ${REMOTE_HOME}/btcpay.complete

EOL

# send an updated ~/.bashrc so we have quicker access to cli tools
scp ./bashrc.txt "ubuntu@$FQDN:$REMOTE_HOME/.bashrc"
ssh "$BTCPAY_FQDN" "chown ubuntu:ubuntu $REMOTE_HOME/.bashrc"
ssh "$BTCPAY_FQDN" "chmod 0664 $REMOTE_HOME/.bashrc"

# send the setup script to the remote machine.
scp "$SITE_PATH/btcpay.sh" "ubuntu@$FQDN:$REMOTE_HOME/btcpay_setup.sh"
ssh "$BTCPAY_FQDN" "chmod 0744 $REMOTE_HOME/btcpay_setup.sh"
ssh "$BTCPAY_FQDN" "sudo bash -c $REMOTE_HOME/btcpay_setup.sh"
ssh "$BTCPAY_FQDN" "touch $REMOTE_HOME/btcpay.complete"

# lets give time for the containers to spin up
sleep 10