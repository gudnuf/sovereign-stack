#!/bin/bash

set -e
cd "$(dirname "$0")"

# NOTE! This script MUST be executed as root.
sudo apt-get update
sudo apt-get install -y gnupg ca-certificates curl lsb-release

mkdir -p /etc/apt/keyrings

# add the docker gpg key to keyring for docker-ce-cli
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    cat /home/ubuntu/sovereign-stack/certs/docker.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null 2>&1
fi

# TODO REVIEW mgmt software requirements
sudo apt-get update
sudo apt-get install -y wait-for-it dnsutils rsync sshfs apt-transport-https docker-ce-cli \
    libcanberra-gtk-module snapd nano git

sleep 1

#apt install python3-pip python3-dev libusb-1.0-0-dev libudev-dev pinentry-curses  for trezor stuff
# for trezor installation
#pip3 install setuptools wheel
#pip3 install trezor_agent

# ensure the trezor-t udev rules are in place.
# if [ ! -f /etc/udev/rules.d/51-trezor.rules ]; then
#     sudo cp ./51-trezor.rules /etc/udev/rules.d/51-trezor.rules
# fi

# install snap
if ! snap list | grep -q lxd; then
    sudo snap install lxd --channel=5.10/stable
    sleep 6

    # We just do an auto initialization. All we are using is the LXD client inside the management environment.
    sudo lxd init --auto
fi

# run a lxd command so we don't we a warning upon first invocation
lxc list > /dev/null 2>&1


# add groups for docker and lxd
if ! groups ubuntu | grep -q docker; then
    sudo addgroup docker
    sudo usermod -aG docker ubuntu
    sudo usermod -aG lxd ubuntu
fi


# if an SSH pubkey does not exist, we create one.
if [ ! -f /home/ubuntu/.ssh/id_rsa.pub ]; then
    # generate a new SSH key for the base vm image.
    ssh-keygen -f /home/ubuntu/.ssh/id_rsa -t ecdsa -b 521 -N ""
fi

echo "Your management machine has been provisioned!"