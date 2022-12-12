#!/bin/bash

set -eu
cd "$(dirname "$0")"

# let's check to ensure the management machine is on the Baseline ubuntu 21.04
if ! lsb_release -d | grep -q "Ubuntu 22.04 LTS"; then
    echo "ERROR: Your machine is not running the Ubuntu 22.04 LTS baseline OS on your management machine."
    exit 1
fi

if [ ! -f /usr/share/keyrings/docker-archive-keyring.gpg ]; then
    cat ./certs/docker.gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

sudo apt-get update

# TODO REVIEW management machine software requirements
# to a host on SERVERS LAN so that it can operate
# TODO document which dependencies are required by what software, e.g., trezor, docker, etc.
# virt-manager allows us to run type-1 vms desktop version. We use remote viewer to get a GUI for the VM
sudo apt-get install -y wait-for-it dnsutils rsync sshfs curl gnupg \
                        apt-transport-https ca-certificates lsb-release docker-ce-cli  \
                        python3-pip python3-dev libusb-1.0-0-dev libudev-dev pinentry-curses \
                        libcanberra-gtk-module virt-manager pass


# for trezor installation
pip3 install setuptools wheel
pip3 install trezor_agent

if [ ! -f /etc/udev/rules.d/51-trezor.rules ]; then
    sudo cp ./51-trezor.rules /etc/udev/rules.d/51-trezor.rules
fi

# TODO initialize pass here; need to first initialize Trezor-T certificates.


# install lxd as a snap if it's not installed. We only really use the client part of this package
# on the management machine.
if ! snap list | grep -q lxd; then
    sudo snap install lxd --candidate

    # initialize the daemon for auto use. Most of the time on the management machine,
    # we only use the LXC client -- not the daemon. HOWEVER, there are circustances where
    # you might want to run the management machine in a LXD-based VM. We we init the lxd daemon
    # after havning installed it so it'll be available for use.
    # see https://www.sovereign-stack.org/management/
    sudo lxd init --auto --storage-pool=default --storage-create-loop=50 --storage-backend=zfs
fi

# make the Sovereign Stack commands available to the user via ~/.bashrc
# we use ~/.bashrc
ADDED_COMMAND=false
for SS_COMMAND in deploy cluster; do
    if ! < "$HOME/.bashrc" grep -q "ss-$SS_COMMAND"; then
        echo "alias ss-${SS_COMMAND}='$(pwd)/${SS_COMMAND}.sh \$@'" >> "$HOME/.bashrc"
        ADDED_COMMAND=true
    fi
done

if [ "$ADDED_COMMAND" = true ]; then
    echo "WARNING! You need to run 'source ~/.bashrc' before continuing."
fi
