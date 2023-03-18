#!/bin/bash

set -exu
cd "$(dirname "$0")"

# see https://www.sovereign-stack.org/management/

# this script is not meant to be executed from the SSME; Let's let's check and abort if so.
if [ "$(hostname)" = ss-mgmt ]; then
    echo "ERROR: This command is meant to be executed from the bare metal management machine -- not the SSME."
    exit 1
fi

. ./defaults.sh

# the DISK variable here tells us which disk (partition) the admin wants to use for 
# lxd resources. By default, we provision the disk under / as a loop device. Admin
# can override with CLI modifications.
DISK="rpool/lxd"

#DISK="/dev/sda1"

export DISK="$DISK"

# let's check to ensure the management machine is on the Baseline ubuntu
# TODO maybe remove this check; this theoretically should work on anything that support bash and lxd?
if ! lsb_release -d | grep -q "Ubuntu 22.04"; then
    echo "ERROR: Your machine is not running the Ubuntu 22.04 LTS baseline OS on your management machine."
    exit 1
fi

# install lxd snap and initialize it
if ! snap list | grep -q lxd; then
    sudo snap install lxd
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


# we need to get the base image. IMport it if it's cached, else download it then cache it.
if ! lxc image list | grep -q "$UBUNTU_BASE_IMAGE_NAME"; then
    # if the image if cached locally, import it from disk, otherwise download it from ubuntu
    if [ -d "$SS_JAMMY_PATH" ]; then
        lxc image import "$SS_JAMMY_PATH/meta-bf1a2627bdddbfb0a9bf1f8ae146fa794800c6c91281d3db88c8d762f58bd057.tar.xz" \
            "$SS_JAMMY_PATH/bf1a2627bdddbfb0a9bf1f8ae146fa794800c6c91281d3db88c8d762f58bd057.qcow2" \
            --alias "$UBUNTU_BASE_IMAGE_NAME"
    else
        lxc image copy "images:$BASE_LXC_IMAGE" local: --alias "$UBUNTU_BASE_IMAGE_NAME" --vm --auto-update
    fi
fi

# export the image if it's not cached.
if [ ! -d "$SS_JAMMY_PATH" ]; then
    mkdir "$SS_JAMMY_PATH" 
    lxc image export "$UBUNTU_BASE_IMAGE_NAME" "$SS_JAMMY_PATH" --vm
fi

# if the ss-mgmt doesn't exist, create it.
SSH_PUBKEY_PATH="$HOME/.ssh/id_rsa.pub"
if ! lxc list --format csv | grep -q ss-mgmt; then
    lxc init "images:$BASE_LXC_IMAGE" ss-mgmt --vm -c limits.cpu=4 -c limits.memory=4GiB --profile=default

    # mount the pre-verified sovereign stack git repo into the new vm
    lxc config device add ss-mgmt sscode disk source="$(pwd)" path=/home/ubuntu/sovereign-stack

    # if the System Owner has a ~/.ss directory, then we'll mount it into the vm
    # this allows the data to persist across ss-mgmt vms; ie. install/uninstall
    if [ -d "$SS_ROOT_PATH" ]; then
        lxc config device add ss-mgmt ssroot disk source="$SS_ROOT_PATH" path=/home/ubuntu/.ss
    fi

    # if a ~/.bitcoin/testnet3/blocks direrectory exists, mount it in.
    BITCOIN_TESTNET_BLOCKS_PATH="$HOME/.bitcoin/testnet3/blocks"
    if [ -d "$BITCOIN_TESTNET_BLOCKS_PATH" ]; then
        lxc config device add ss-mgmt ss-testnet-blocks disk source="$BITCOIN_TESTNET_BLOCKS_PATH" path=/home/ubuntu/.ss/cache/bitcoin/testnet/blocks
    fi

        # if a ~/.bitcoin/testnet3/blocks direrectory exists, mount it in.
    BITCOIN_TESTNET_CHAINSTATE_PATH="$HOME/.bitcoin/testnet3/chainstate"
    if [ -d "$BITCOIN_TESTNET_CHAINSTATE_PATH" ]; then
        lxc config device add ss-mgmt ss-testnet-chainstate disk source="$BITCOIN_TESTNET_CHAINSTATE_PATH" path=/home/ubuntu/.ss/cache/bitcoin/testnet/chainstate
    fi

    # mount the ssh directory in there.
    if [ -f "$SSH_PUBKEY_PATH" ]; then
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

# wait for the VM to complete its default cloud-init.
while lxc exec ss-mgmt -- [ ! -f /var/lib/cloud/instance/boot-finished ]; do
    sleep 1
done

# do some other preparations for user experience
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

wait-for-it -t 300 "$IP_V4_ADDRESS:22" > /dev/null 2>&1

# Let's remove any entry in our known_hosts, then add it back.
# we are using IP address here so we don't have to rely on external DNS 
# configuration for the base image preparataion.
ssh-keygen -R "$IP_V4_ADDRESS"

ssh-keyscan -H -t ecdsa "$IP_V4_ADDRESS" >> "$SSH_HOME/known_hosts"

ssh "ubuntu@$IP_V4_ADDRESS" sudo chown -R ubuntu:ubuntu /home/ubuntu

ssh "ubuntu@$IP_V4_ADDRESS" /home/ubuntu/sovereign-stack/management/provision.sh

#lxc restart ss-mgmt

if [ "$ADDED_COMMAND" = true ]; then
    echo "NOTICE! You need to run 'source ~/.bashrc' before continuing. After that, type 'ss-manage' to enter your management environment."
fi

. ./defaults.sh
# As part of the install script, we pull down any other sovereign-stack git repos
PROJECTS_SCRIPTS_REPO_URL="https://git.sovereign-stack.org/ss/project"
PROJECTS_SCRIPTS_PATH="$(pwd)/deployment/project"
if [ ! -d "$PROJECTS_SCRIPTS_PATH" ]; then
    git clone "$PROJECTS_SCRIPTS_REPO_URL" "$PROJECTS_SCRIPTS_PATH"
else
    cd "$PROJECTS_SCRIPTS_PATH"
    git -c advice.detachedHead=false pull origin main
    git checkout "$TARGET_PROJECT_GIT_COMMIT"
    cd -
fi