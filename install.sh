#!/bin/bash

sudo apt-get update

sudo apt-get install -y wait-for-it dnsutils tor rsync sshfs

if [ ! -f $(which lxd) ]; then
    sudo snap install lxd
fi

# let's ensure docker-machine is available.
base="https://github.com/docker/machine/releases/download/v0.16.2"
curl -L "$base/docker-machine-$(uname -s)-$(uname -m)" >/tmp/docker-machine
sudo mv /tmp/docker-machine /usr/local/bin/docker-machine
chmod +x /usr/local/bin/docker-machine

# NOTE!!! DOCKER CLI MUST BE INSTALLED VIA instructions at https://docs.docker.com/engine/install/ubuntu/  DO NOT USE SNAP
sudo apt-get remove docker docker-engine docker.io containerd runc
sudo apt-get update
sudo apt-get install apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce-cli -y

# install trezor requirements https://wiki.trezor.io/Apps:SSH_agent
sudo apt update && sudo apt install python3-pip libusb-1.0-0-dev libudev-dev pinentry-curses
pip3 install trezor_agent

sudo cp ./51-trezor.rules /etc/udev/rules.d/51-trezor.rules
