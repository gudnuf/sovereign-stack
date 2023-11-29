#!/bin/bash

set -e
cd "$(dirname "$0")"

# NOTE! This script MUST be executed as root.
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release jq bc

sudo mkdir -m 0755 -p /etc/apt/keyrings

# add the docker gpg key to keyring for docker-ce-cli
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    cat /home/ubuntu/sovereign-stack/certs/docker.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null 2>&1
fi

# TODO REVIEW mgmt software requirements
sudo apt-get update
sudo apt-get install -y wait-for-it dnsutils rsync sshfs apt-transport-https docker-ce-cli libcanberra-gtk-module nano git

sudo bash -c "$HOME/sovereign-stack/install_incus.sh"

sudo incus admin init --minimal

# add groups for docker and lxd
if ! grep -q "^docker:" /etc/group; then
    sudo groupadd docker
fi

# add groups for docker and lxd
if ! grep -q "^incus-admin:" /etc/group; then
    sudo groupadd incus-admin
fi

if ! groups ubuntu | grep -q "\bdocker\b"; then
    sudo usermod -aG docker ubuntu
fi

if ! groups ubuntu | grep -q "\bincus-admin\b"; then
    sudo usermod -aG incus-admin ubuntu
fi
