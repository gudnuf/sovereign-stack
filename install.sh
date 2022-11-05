#!/bin/bash

set -e
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
# is docker-ce actually needed here? prefer to move docker registry
# to a host on SERVERS LAN so that it can operate
# TODO document which dependencies are required by what software, e.g., trezor, docker, etc.
sudo apt-get install -y wait-for-it dnsutils rsync sshfs curl gnupg \
                        apt-transport-https ca-certificates lsb-release \
                        docker-ce-cli docker-ce containerd.io docker-compose-plugin \
                        python3-pip python3-dev libusb-1.0-0-dev libudev-dev pinentry-curses \
                        libcanberra-gtk-module

# for trezor installation
pip3 install setuptools wheel
pip3 install trezor_agent

if [ ! -f /etc/udev/rules.d/51-trezor.rules ]; then
    sudo cp ./51-trezor.rules /etc/udev/rules.d/51-trezor.rules
fi

# install lxd as a snap if it's not installed. We only really use the client part of this package
# on the management machine.
if ! snap list | grep -q lxd; then
    sudo snap install lxd --candidate
fi

# make ss-deploy available to the user
if ! groups | grep -q docker; then
    sudo groupadd docker
fi

sudo usermod -aG docker "$USER"

# make the Sovereign Stack commands available to the user.
# we use ~/.bashrc
ADDED_COMMAND=false
if ! < "$HOME/.bashrc" grep -q "ss-deploy"; then
    echo "alias ss-deploy='/home/$USER/sovereign-stack/deploy.sh \$@'" >> "$HOME/.bashrc"
    ADDED_COMMAND=true
fi

if ! < "$HOME/.bashrc" grep -q "ss-cluster"; then
    echo "alias ss-cluster='/home/$USER/sovereign-stack/cluster.sh \$@'" >> "$HOME/.bashrc"
    ADDED_COMMAND=true
fi

if ! < "$HOME/.bashrc" grep -q "ss-projects"; then
    echo "alias ss-projects='/home/$USER/sovereign-stack/projects.sh \$@'" >> "$HOME/.bashrc"
    ADDED_COMMAND=true
fi

if [ "$ADDED_COMMAND" = true ]; then
    echo "WARNING! You need to run 'source ~/.bashrc' before continuing."
fi