#!/bin/bash

set -eu
cd "$(dirname "$0")"

# https://www.sovereign-stack.org/install/

# this script is not meant to be executed from the SSME; Let's let's check and abort if so.
if [ "$(hostname)" = ss-mgmt ]; then
    echo "ERROR: This command is meant to be executed from the bare metal management machine -- not the SSME."
    exit 1
fi

DISK_OR_PARTITION=
DISK=loop

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --disk-or-partition=*)
            DISK_OR_PARTITION="${i#*=}"
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done


# ensure the iptables forward policy is set to ACCEPT so your host can act as a router
# Note this is necessary if docker is running (or has been previuosly installed) on the
# same host running LXD.
sudo iptables -F FORWARD
sudo iptables -P FORWARD ACCEPT


# if the user didn't specify the disk or partition, we create a loop device under
# the user's home directory. If the user does specify a disk or partition, we will
# create the ZFS pool there.
if [ -z "$DISK_OR_PARTITION" ]; then
    DISK="$DISK_OR_PARTITION"
fi

export DISK="$DISK"

# install lxd snap and initialize it
if ! snap list | grep -q lxd; then
    sudo snap install lxd --channel=5.17/stable
    sleep 5

    # run lxd init
    cat <<EOF | lxd init --preseed
config: {}
networks:
- config:
    ipv4.address: auto
    ipv4.dhcp: true
    ipv4.nat: true
    ipv6.address: none
  description: "Default network bridge for ss-mgmt outbound network access."
  name: lxdbr0
  type: bridge
storage_pools:
- config:
    source: ${DISK}
  description: ""
  name: sovereign-stack
  driver: zfs
profiles:
- config: {}
  description: ""
  devices:
    enp5s0:
      name: enp5s0
      network: lxdbr0
      type: nic
    root:
      path: /
      pool: sovereign-stack
      type: disk
  name: default
projects: []

EOF

fi

. ./deployment/deployment_defaults.sh

. ./deployment/base.sh



# we need to get the base image. IMport it if it's cached, else download it then cache it.
if ! lxc image list | grep -q "$UBUNTU_BASE_IMAGE_NAME"; then
        # if the image if cached locally, import it from disk, otherwise download it from ubuntu
    IMAGE_PATH="$HOME/ss/cache/ss-ubuntu-jammy"
    IMAGE_IDENTIFIER=$(find "$IMAGE_PATH" | grep ".qcow2" | head -n1 | cut -d "." -f1)
    METADATA_FILE="$IMAGE_PATH/meta-$IMAGE_IDENTIFIER.tar.xz"
    IMAGE_FILE="$IMAGE_PATH/$IMAGE_IDENTIFIER.qcow2"
    if [ -d "$IMAGE_PATH" ] && [ -f "$METADATA_FILE" ] && [ -f "$IMAGE_FILE" ]; then
        lxc image import "$METADATA_FILE" "$IMAGE_FILE" --alias "$UBUNTU_BASE_IMAGE_NAME"
    else
        lxc image copy "images:$BASE_LXC_IMAGE" local: --alias "$UBUNTU_BASE_IMAGE_NAME" --vm --auto-update
        mkdir -p "$IMAGE_PATH"
        lxc image export "$UBUNTU_BASE_IMAGE_NAME" "$IMAGE_PATH" --vm
    fi
fi

# if the ss-mgmt doesn't exist, create it.
SSH_PATH="$HOME/.ssh"
SSH_PRIVKEY_PATH="$SSH_PATH/id_rsa"
SSH_PUBKEY_PATH="$SSH_PRIVKEY_PATH.pub"

if [ ! -f "$SSH_PRIVKEY_PATH" ]; then
    ssh-keygen -f "$SSH_PRIVKEY_PATH" -t rsa -b 4096
fi

chmod 700 "$HOME/.ssh"
chmod 600 "$HOME/.ssh/config"

# add SSH_PUBKEY_PATH to authorized_keys
grep -qxF "$(cat $SSH_PUBKEY_PATH)" "$SSH_PATH/authorized_keys" || cat "$SSH_PUBKEY_PATH" >> "$SSH_PATH/authorized_keys"

FROM_BUILT_IMAGE=false
if ! lxc list --format csv | grep -q ss-mgmt; then

    # TODO check to see if there's an existing ss-mgmt image to spawn from, otherwise do this.
    if lxc image list | grep -q ss-mgmt; then
        FROM_BUILT_IMAGE=true
        lxc init ss-mgmt ss-mgmt --vm -c limits.cpu=4 -c limits.memory=4GiB --profile=default
    else
        lxc init "images:$BASE_LXC_IMAGE" ss-mgmt --vm -c limits.cpu=4 -c limits.memory=4GiB --profile=default
    fi

fi

# mount the pre-verified sovereign stack git repo into the new vm
if ! lxc config device show ss-mgmt | grep -q ss-code; then
    lxc config device add ss-mgmt ss-code disk source="$(pwd)" path=/home/ubuntu/sovereign-stack
fi

# create the ~/ss path and mount it into the vm.
source ./deployment/deployment_defaults.sh
source ./deployment/base.sh

mkdir -p "$SS_ROOT_PATH"

if ! lxc config device show ss-mgmt | grep -q ss-root; then
    lxc config device add ss-mgmt ss-root disk source="$SS_ROOT_PATH" path=/home/ubuntu/ss
fi

# if a ~/.bitcoin/testnet3/blocks direrectory exists, mount it in.
BITCOIN_DIR="$HOME/.bitcoin"
REMOTE_BITCOIN_CACHE_PATH="/home/ubuntu/ss/cache/bitcoin"
BITCOIN_TESTNET_BLOCKS_PATH="$BITCOIN_DIR/testnet3/blocks"
if [ -d "$BITCOIN_TESTNET_BLOCKS_PATH" ]; then
    if ! lxc config device show ss-mgmt | grep -q ss-testnet-blocks; then
        lxc config device add ss-mgmt ss-testnet-blocks disk source="$BITCOIN_TESTNET_BLOCKS_PATH" path=$REMOTE_BITCOIN_CACHE_PATH/testnet/blocks
    fi
fi

# if a ~/.bitcoin/testnet3/blocks direrectory exists, mount it in.
BITCOIN_TESTNET_CHAINSTATE_PATH="$BITCOIN_DIR/testnet3/chainstate"
if [ -d "$BITCOIN_TESTNET_CHAINSTATE_PATH" ]; then
    if ! lxc config device show ss-mgmt | grep -q ss-testnet-chainstate; then
        lxc config device add ss-mgmt ss-testnet-chainstate disk source="$BITCOIN_TESTNET_CHAINSTATE_PATH" path=$REMOTE_BITCOIN_CACHE_PATH/testnet/chainstate
    fi
fi

# if a ~/.bitcoin/blocks dir exists, mount it in.
BITCOIN_MAINNET_BLOCKS_PATH="$BITCOIN_DIR/blocks"
if [ -d "$BITCOIN_MAINNET_BLOCKS_PATH" ]; then
    if ! lxc config device show ss-mgmt | grep -q ss-mainnet-blocks; then
        lxc config device add ss-mgmt ss-mainnet-blocks disk source="$BITCOIN_MAINNET_BLOCKS_PATH" path=$REMOTE_BITCOIN_CACHE_PATH/mainnet/blocks
    fi
fi

    # if a ~/.bitcoin/testnet3/blocks direrectory exists, mount it in.
BITCOIN_MAINNET_CHAINSTATE_PATH="$BITCOIN_DIR/chainstate"
if [ -d "$BITCOIN_MAINNET_CHAINSTATE_PATH" ]; then
    if ! lxc config device show ss-mgmt | grep -q ss-mainnet-blocks; then
        lxc config device add ss-mgmt ss-mainnet-chainstate disk source="$BITCOIN_MAINNET_CHAINSTATE_PATH" path=$REMOTE_BITCOIN_CACHE_PATH/mainnet/chainstate
    fi
fi

# mount the ssh directory in there.
if [ -f "$SSH_PUBKEY_PATH" ]; then
    if ! lxc config device show ss-mgmt | grep -q ss-ssh; then
        lxc config device add ss-mgmt ss-ssh disk source="$HOME/.ssh" path=/home/ubuntu/.ssh
    fi
fi

# start the vm if it's not already running
if lxc list --format csv | grep -q "ss-mgmt,STOPPED"; then
    lxc start ss-mgmt
    sleep 10
fi

# wait for the vm to have an IP address
. ./management/wait_for_lxc_ip.sh

# do some other preparations for user experience
lxc file push ./management/bash_aliases ss-mgmt/home/ubuntu/.bash_aliases
lxc file push ./management/bash_profile ss-mgmt/home/ubuntu/.bash_profile
lxc file push ./management/bashrc ss-mgmt/home/ubuntu/.bashrc
lxc file push ./management/motd ss-mgmt/etc/update-motd.d/sovereign-stack

# install SSH
lxc exec ss-mgmt apt-get update
lxc exec ss-mgmt -- apt-get install -y openssh-server
lxc file push ./management/sshd_config ss-mgmt/etc/ssh/sshd_config
lxc exec ss-mgmt -- sudo systemctl restart sshd

# add 'ss-manage' to the bare metal ~/.bashrc
ADDED_COMMAND=false
if ! < "$HOME/.bashrc" grep -q "ss-manage"; then
    echo "alias ss-manage='$(pwd)/manage.sh \$@'" >> "$HOME/.bashrc"
    ADDED_COMMAND=true
fi

# Let's remove any entry in our known_hosts, then add it back.
# we are using IP address here so we don't have to rely on external DNS 
# configuration for the base image preparataion.
ssh-keygen -R "$IP_V4_ADDRESS"

ssh-keyscan -H "$IP_V4_ADDRESS" >> "$SSH_HOME/known_hosts"

ssh "ubuntu@$IP_V4_ADDRESS" sudo chown -R ubuntu:ubuntu /home/ubuntu


if [ "$FROM_BUILT_IMAGE" = false ]; then
    ssh "ubuntu@$IP_V4_ADDRESS" /home/ubuntu/sovereign-stack/management/provision.sh

    lxc stop ss-mgmt

    if ! lxc image list | grep -q "ss-mgmt"; then
        echo "Publishing image. Please wait, this may take a while..."
        lxc publish ss-mgmt --alias=ss-mgmt
    fi

    lxc start ss-mgmt
fi

if [ "$ADDED_COMMAND" = true ]; then
    echo "NOTICE! You need to run 'source ~/.bashrc' before continuing. After that, type 'ss-manage' to enter your management environment."
fi
