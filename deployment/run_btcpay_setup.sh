#!/bin/bash

set -e


# export BTCPAY_FASTSYNC_ARCHIVE_FILENAME="utxo-snapshot-bitcoin-testnet-1445586.tar"
# BTCPAY_REMOTE_RESTORE_PATH="/var/lib/docker/volumes/generated_bitcoin_datadir/_data"

# This is the config for a basic proxy to the listening port 127.0.0.1:2368
# It also supports modern TLS, so SSL certs must be available.
cat > "$SITE_PATH/btcpay.sh" <<EOL
#!/bin/bash

set -e

# wait for cloud-init to complete yo
while [ ! -f /var/lib/cloud/instance/boot-finished ]; do
    sleep 1
done

# get pre-reqs
apt-get update && apt-get install -y git wget

if [ -d "btcpayserver-docker" ] && [ "$EXISTING_BRANCH" != "master" ] && [ "$EXISTING_REMOTE" != "master" ]; then echo "existing btcpayserver-docker folder found that did not match our specified fork. Moving. (Current branch: $EXISTING_BRANCH, Current remote: $EXISTING_REMOTE)"; mv "btcpayserver-docker" "btcpayserver-docker_$(date +%s)"; fi
if [ -d "btcpayserver-docker" ] && [ "$EXISTING_BRANCH" == "master" ] && [ "$EXISTING_REMOTE" == "master" ]; then echo "existing btcpayserver-docker folder found, pulling instead of cloning."; git pull; fi
if [ ! -d "btcpayserver-docker" ]; then echo "cloning btcpayserver-docker"; git clone -b master https://github.com/btcpayserver/btcpayserver-docker btcpayserver-docker; fi

export BTCPAY_HOST="${FQDN}"
export NBITCOIN_NETWORK="${BTC_CHAIN}"
export LIGHTNING_ALIAS="${DOMAIN_NAME}"
export LETSENCRYPT_EMAIL="${CERTIFICATE_EMAIL_ADDRESS}"
export BTCPAYGEN_LIGHTNING="clightning"
export BTCPAYGEN_CRYPTO1="btc"

# opt-save-storage keeps 1 year of blocks (prunes to 100 GB)
# opt-add-btctransmuter adds transmuter software
# 
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="${BTCPAYGEN_ADDITIONAL_FRAGMENTS}"
export BTCPAY_ADDITIONAL_HOSTS="${BTCPAY_ADDITIONAL_HOSTNAMES}"
export BTCPAY_ENABLE_SSH=true

cd btcpayserver-docker

# run fast_sync if it's not been done before.
if [ ! -f /home/ubuntu/fast_sync_completed ]; then
    cd ./contrib/FastSync
    ./load-utxo-set.sh
    touch /home/ubuntu/fast_sync_completed
    cd -
fi

# provision the btcpay server
. ./btcpay-setup.sh -i

EOL

# send the setup script to the remote machine.
scp "$SITE_PATH/btcpay.sh" "ubuntu@$FQDN:$REMOTE_HOME/btcpay_setup.sh"
ssh "$FQDN" "chmod 0744 $REMOTE_HOME/btcpay_setup.sh"
ssh "$FQDN" "sudo bash -c ./btcpay_setup.sh"
