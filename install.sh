#!/bin/bash

set -ex
cd "$(dirname "$0")"

sudo apt-get remove docker docker-engine docker.io containerd runc

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

sudo apt-get install -y wait-for-it dnsutils rsync sshfs apt-transport-https ca-certificates curl gnupg lsb-release docker-ce-cli python3-pip libusb-1.0-0-dev pinentry-curses
#libudev-dev

# install lxd as a snap if it's not installed. We only really use the LXC part of this package.
if ! snap list | grep -q lxd; then
    sudo snap install lxd
fi

# let's ensure docker-machine is available. This is only temporary though.
curl -L https://github.com/docker/machine/releases/download/v0.16.2/docker-machine-$(uname -s)-$(uname -m) >/tmp/docker-machine &&
    chmod +x /tmp/docker-machine &&
    sudo cp /tmp/docker-machine /usr/local/bin/docker-machine


# base="https://github.com/docker/machine/releases/download/v0.16.2"
# curl -s -L "$base/docker-machine-$(uname -s)-$(uname -m)" >/tmp/docker-machine
# sudo mv /tmp/docker-machine /usr/local/bin/docker-machine
# chmod +x /usr/local/bin/docker-machine

pip3 install trezor_agent

sudo cp ./51-trezor.rules /etc/udev/rules.d/51-trezor.rules

# if there's a ./env file here, let's execute it. Admins can put various deployment-specific things there.
if [ ! -f "$(pwd)/env" ]; then
    echo "#!/bin/bash" >> "$(pwd)/env"
    chmod 0744 "$(pwd)/env"
    echo "We stubbed out a '$(pwd)/env' file for you. Put any LXD-remote specific information in there."
    echo "Check out 'https://www.sovereign-stack.org/env' for an example."
    exit 1
fi