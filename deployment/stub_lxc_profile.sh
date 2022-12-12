#!/bin/bash

set -eu

LXD_HOSTNAME="$1"

# generate the custom cloud-init file. Cloud init installs and configures sshd
SSH_AUTHORIZED_KEY=$(<"$SSH_HOME/id_rsa.pub")
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

# if VIRTUAL_MACHINE=sovereign-stack then we are building the base image.
if [ "$LXD_HOSTNAME" = "sovereign-stack" ]; then
    # this is for the base image only...
    cat >> "$YAML_PATH" <<EOF
  user.vendor-data: |
    #cloud-config
    apt_mirror: http://us.archive.ubuntu.com/ubuntu/
    package_update: true
    package_upgrade: false
    package_reboot_if_required: false

    preserve_hostname: false
    fqdn: sovereign-stack

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
      - path: /home/ubuntu/docker.asc
        content: |
              -----BEGIN PGP PUBLIC KEY BLOCK-----

              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
              YT90qFF93M3v01BbxP+EIY2/9tiIPbrd
              =0YYh
              -----END PGP PUBLIC KEY BLOCK-----

      - path: /etc/ssh/ssh_config
        content: |
              Port 22
              ListenAddress 0.0.0.0
              Protocol 2
              ChallengeResponseAuthentication no
              PasswordAuthentication no
              UsePAM no
              LogLevel INFO

      - path: /etc/docker/daemon.json
        content: |
              {
                "registry-mirrors": [
                  "${REGISTRY_URL}"
                ]
              }

    runcmd:
      - cat /home/ubuntu/docker.asc | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
      - sudo rm /home/ubuntu/docker.asc
      - echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
      - sudo apt-get update
      - sudo apt-get install -y docker-ce docker-ce-cli containerd.io
      - echo "alias ll='ls -lah'" >> /home/ubuntu/.bash_profile
      - sudo curl -s -L "https://github.com/docker/compose/releases/download/1.21.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      - sudo chmod +x /usr/local/bin/docker-compose
      - sudo apt-get install -y openssh-server
      

EOF

else 
    # all other machines.
    cat >> "$YAML_PATH" <<EOF
  user.vendor-data: |
    #cloud-config
    apt_mirror: http://us.archive.ubuntu.com/ubuntu/
    package_update: false
    package_upgrade: false
    package_reboot_if_required: false

    preserve_hostname: false
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
    pool: sovereign-stack
    type: disk
  config:
    source: cloud-init:config
    type: disk
EOF

# Stub out the network piece for the base image.
if [ "$LXD_HOSTNAME" = sovereign-stack ] ; then

# If we are deploying the www, we attach the vm to the underlay via macvlan.
cat >> "$YAML_PATH" <<EOF
  enp5s0:
    name: enp5s0
    nictype: macvlan
    parent: ${DATA_PLANE_MACVLAN_INTERFACE}
    type: nic
name: ${FILENAME}
EOF

else
# If we are deploying the www, we attach the vm to the underlay via macvlan.
cat >> "$YAML_PATH" <<EOF
  enp5s0:
    nictype: macvlan
    parent: ${DATA_PLANE_MACVLAN_INTERFACE}
    type: nic
  enp6s0:
    name: enp6s0
    network: lxdbrSS
    type: nic

name: ${FILENAME}
EOF

fi

# let's create a profile for the BCM TYPE-1 VMs. This is per VM.
if ! lxc profile list --format csv | grep -q "$LXD_HOSTNAME"; then
    lxc profile create "$LXD_HOSTNAME"

    # configure the profile with our generated cloud-init.yml file.
    cat "$YAML_PATH" | lxc profile edit "$LXD_HOSTNAME" 

fi
