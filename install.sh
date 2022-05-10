#!/bin/bash

sudo apt-get remove docker docker-engine docker.io containerd runc

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

sudo apt-get install -y wait-for-it dnsutils rsync sshfs apt-transport-https ca-certificates curl gnupg lsb-release  docker-ce-cli python3-pip libusb-1.0-0-dev libudev-dev pinentry-curses

if [ ! -f $(which lxd) ]; then
    sudo snap install lxd
fi

# let's ensure docker-machine is available.
base="https://github.com/docker/machine/releases/download/v0.16.2"
curl -s -L "$base/docker-machine-$(uname -s)-$(uname -m)" >/tmp/docker-machine
sudo mv /tmp/docker-machine /usr/local/bin/docker-machine
chmod +x /usr/local/bin/docker-machine

pip3 install trezor_agent

sudo cp ./51-trezor.rules /etc/udev/rules.d/51-trezor.rules
