#!/bin/bash

set -ex
cd "$(dirname "$0")"

# export BTCPAY_FASTSYNC_ARCHIVE_FILENAME="utxo-snapshot-bitcoin-testnet-1445586.tar"
# BTCPAY_REMOTE_RESTORE_PATH="/var/lib/docker/volumes/generated_bitcoin_datadir/_data"

# This is the config for a basic proxy to the listening port 127.0.0.1:2368
# It also supports modern TLS, so SSL certs must be available.
cat > "$SITE_PATH/btcpay.sh" <<EOL
#!/bin/bash

set -ex
cd "\$(dirname "\$0")"

# wait for cloud-init to complete yo
while [ ! -f /var/lib/cloud/instance/boot-finished ]; do
    sleep 1
done

#curl -SL https://github.com/docker/compose/releases/download/v2.6.1/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
#chmod 0777 /usr/local/bin/docker-compose

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

export BTCPAY_HOST="${FQDN}"
export NBITCOIN_NETWORK="${BTC_CHAIN}"
export LIGHTNING_ALIAS="${DOMAIN_NAME}"
export LETSENCRYPT_EMAIL="${CERTIFICATE_EMAIL_ADDRESS}"
export BTCPAYGEN_LIGHTNING="clightning"
export BTCPAYGEN_CRYPTO1="btc"

export BTCPAYGEN_ADDITIONAL_FRAGMENTS="opt-save-storage;opt-add-btctransmuter;opt-add-nostr-relay;opt-add-tor-relay"
#export BTCPAYGEN_EXCLUDE_FRAGMENTS="nginx-https"
export BTCPAY_ADDITIONAL_HOSTS="${BTCPAY_ADDITIONAL_HOSTNAMES}"
export BTCPAYGEN_REVERSEPROXY="nginx"
export BTCPAY_ENABLE_SSH=false
export BTCPAY_BASE_DIRECTORY=${REMOTE_HOME}

if [ "\$NBITCOIN_NETWORK" != regtest ]; then
    # run fast_sync if it's not been done before.
    if [ ! -f /home/ubuntu/fast_sync_completed ]; then
        cd ./contrib/FastSync
        ./load-utxo-set.sh
        touch /home/ubuntu/fast_sync_completed
        cd -
    fi
fi

# provision the btcpayserver
. ./btcpay-setup.sh -i

sleep 15
EOL

# send the setup script to the remote machine.
scp "$SITE_PATH/btcpay.sh" "ubuntu@$FQDN:$REMOTE_HOME/btcpay_setup.sh"
ssh "$FQDN" "chmod 0744 $REMOTE_HOME/btcpay_setup.sh"
ssh "$FQDN" "sudo bash -c ./btcpay_setup.sh"
