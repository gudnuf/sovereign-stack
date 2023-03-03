#!/bin/bash

set -exu
cd "$(dirname "$0")"

LXD_HOSTNAME="${1:-}"

# generate the custom cloud-init file. Cloud init installs and configures sshd
SSH_AUTHORIZED_KEY=$(<"$SSH_PUBKEY_PATH")
eval "$(ssh-agent -s)"
ssh-add "$SSH_HOME/id_rsa"
export SSH_AUTHORIZED_KEY="$SSH_AUTHORIZED_KEY"

export FILENAME="$LXD_HOSTNAME.yml"
mkdir -p "$PROJECT_PATH/cloud-init"
YAML_PATH="$PROJECT_PATH/cloud-init/$FILENAME"

# If we are deploying the www, we attach the vm to the underlay via macvlan.
cat > "$YAML_PATH" <<EOF
config:
EOF


if [ "$VIRTUAL_MACHINE" = www ]; then
    cat >> "$YAML_PATH" <<EOF
  limits.cpu: "${WWW_SERVER_CPU_COUNT}"
  limits.memory: "${WWW_SERVER_MEMORY_MB}MB"

EOF

else [ "$VIRTUAL_MACHINE" = btcpayserver ];
    cat >> "$YAML_PATH" <<EOF
  limits.cpu: "${BTCPAY_SERVER_CPU_COUNT}"
  limits.memory: "${BTCPAY_SERVER_MEMORY_MB}MB"

EOF

fi

if [ "$LXD_HOSTNAME" = "$BASE_IMAGE_VM_NAME" ]; then
    # this is for the base image only...
    cat >> "$YAML_PATH" <<EOF
  user.vendor-data: |
    #cloud-config
    apt_mirror: http://us.archive.ubuntu.com/ubuntu/
    package_update: true
    package_upgrade: false
    package_reboot_if_required: false

    preserve_hostname: false
    fqdn: ${BASE_IMAGE_VM_NAME}

    packages:
      - curl
      - ssh-askpass
      - apt-transport-https
      - ca-certificates
      - gnupg-agent
      - software-properties-common
      - lsb-release
      - net-tools
      - htop
      - rsync
      - duplicity
      - sshfs
      - fswatch
      - jq
      - git
      - nano
      - wait-for-it
      - dnsutils
      - wget

    groups:
      - docker

    users:
      - name: ubuntu
        groups: docker
        shell: /bin/bash
        lock_passwd: false
        sudo: ALL=(ALL) NOPASSWD:ALL
        ssh_authorized_keys:
          - ${SSH_AUTHORIZED_KEY}

    write_files:
      - path: /etc/ssh/ssh_config
        content: |
              Port 22
              ListenAddress 0.0.0.0
              Protocol 2
              ChallengeResponseAuthentication no
              PasswordAuthentication no
              UsePAM no
              LogLevel INFO

    runcmd:
      - sudo mkdir -m 0755 -p /etc/apt/keyrings
      - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
      - sudo apt-get update
      - sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      - sudo apt-get install -y openssh-server

EOF


    # apt:
    #   sources:
    #     docker.list:
    #       source: "deb [arch=amd64] https://download.docker.com/linux/ubuntu ${LXD_UBUNTU_BASE_VERSION} stable"
    #       keyid: 9DC858229FC7DD38854AE2D88D81803C0EBFCD88

    #   - path: /etc/docker/daemon.json
    #     content: |
    #           {
    #             "registry-mirrors": ["${REGISTRY_URL}"],
    #             "labels": [ "githead=${LATEST_GIT_COMMIT}" ]
    #           }


#      - sudo apt-get update
      #- sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

else 
    # all other machines.
    cat >> "$YAML_PATH" <<EOF
  user.vendor-data: |
    #cloud-config
    apt_mirror: http://us.archive.ubuntu.com/ubuntu/
    package_update: false
    package_upgrade: false
    package_reboot_if_required: false

    preserve_hostname: true
    fqdn: ${FQDN}

  user.network-config: |
    version: 2
    ethernets:
      enp5s0:
        dhcp4: true
        match:
          macaddress: ${MAC_ADDRESS_TO_PROVISION}
        set-name: enp5s0

      enp6s0:
        dhcp4: false
EOF

    if [[ "$LXD_HOSTNAME" = $WWW_HOSTNAME-* ]]; then
        cat >> "$YAML_PATH" <<EOF
        addresses: [10.139.144.5/24]
        nameservers:
          addresses: [10.139.144.1]
          
EOF
    fi

    if [[ "$LXD_HOSTNAME" = $BTCPAY_HOSTNAME-* ]]; then
        cat >> "$YAML_PATH" <<EOF
        addresses: [10.139.144.10/24]
        nameservers:
          addresses: [10.139.144.1]

EOF
    fi
fi

# If we are deploying the www, we attach the vm to the underlay via macvlan.
cat >> "$YAML_PATH" <<EOF
description: Default LXD profile for ${FILENAME}
devices:
  root:
    path: /
    pool: ss-base
    type: disk
  config:
    source: cloud-init:config
    type: disk
EOF

# Stub out the network piece for the base image.
if [ "$LXD_HOSTNAME" = "$BASE_IMAGE_VM_NAME" ] ; then

# 
cat >> "$YAML_PATH" <<EOF
  enp6s0:
    name: enp6s0
    network: lxdbr0
    type: nic
name: ${FILENAME}
EOF

else
# If we are deploying a VM that attaches to the network underlay.
cat >> "$YAML_PATH" <<EOF
  enp5s0:
    nictype: macvlan
    parent: ${DATA_PLANE_MACVLAN_INTERFACE}
    type: nic
  enp6s0:
    name: enp6s0
    network: lxdbr0
    type: nic

name: ${PRIMARY_DOMAIN}
EOF

fi

# let's create a profile for the BCM TYPE-1 VMs. This is per VM.
if ! lxc profile list --format csv | grep -q "$LXD_HOSTNAME"; then
    lxc profile create "$LXD_HOSTNAME"
fi

# configure the profile with our generated cloud-init.yml file.
cat "$YAML_PATH" | lxc profile edit "$LXD_HOSTNAME" 
