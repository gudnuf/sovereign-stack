#!/bin/bash

set -exu
cd "$(dirname "$0")"

VIRTUAL_MACHINE=base
INCUS_HOSTNAME=
SSDATA_VOLUME_NAME=
BACKUP_VOLUME_NAME=

# grab any modifications from the command line.
for i in "$@"; do
    case $i in
        --lxd-hostname=*)
            INCUS_HOSTNAME="${i#*=}"
            shift
        ;;
        --vm=*)
            VIRTUAL_MACHINE="${i#*=}"
            shift
        ;;
        --ss-volume-name=*)
            SSDATA_VOLUME_NAME="${i#*=}"
            shift
        ;;
        --backup-volume-name=*)
            BACKUP_VOLUME_NAME="${i#*=}"
            shift
        ;;
        *)
        echo "Unexpected option: $1"
        exit 1
        ;;
    esac
done

# generate the custom cloud-init file. Cloud init installs and configures sshd
SSH_AUTHORIZED_KEY=$(<"$SSH_PUBKEY_PATH")
eval "$(ssh-agent -s)" > /dev/null
ssh-add "$SSH_HOME/id_rsa" > /dev/null
export SSH_AUTHORIZED_KEY="$SSH_AUTHORIZED_KEY"

export FILENAME="$INCUS_HOSTNAME.yml"
mkdir -p "$PROJECT_PATH/cloud-init"
YAML_PATH="$PROJECT_PATH/cloud-init/$FILENAME"

# If we are deploying the www, we attach the vm to the underlay via macvlan.
cat > "$YAML_PATH" <<EOF
config:
EOF


if [ "$VIRTUAL_MACHINE" = base ]; then
    cat >> "$YAML_PATH" <<EOF
  limits.cpu: 4
  limits.memory: 4096MB

EOF
fi

if [ "$VIRTUAL_MACHINE" = www ]; then
    cat >> "$YAML_PATH" <<EOF
  limits.cpu: "${WWW_SERVER_CPU_COUNT}"
  limits.memory: "${WWW_SERVER_MEMORY_MB}MB"

EOF
fi

if [ "$VIRTUAL_MACHINE" = btcpayserver ]; then
    cat >> "$YAML_PATH" <<EOF
  limits.cpu: "${BTCPAY_SERVER_CPU_COUNT}"
  limits.memory: "${BTCPAY_SERVER_MEMORY_MB}MB"

EOF

elif [ "$VIRTUAL_MACHINE" = lnplayserver ]; then
    cat >> "$YAML_PATH" <<EOF
  limits.cpu: "${LNPLAY_SERVER_CPU_COUNT}"
  limits.memory: "${LNPLAY_SERVER_MEMORY_MB}MB"

EOF

fi

. ./target.sh

# if VIRTUAL_MACHINE=base, then we doing the base image.
if [ "$VIRTUAL_MACHINE" = base ]; then
    # this is for the base image only...
    cat >> "$YAML_PATH" <<EOF
  user.vendor-data: |
    #cloud-config
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

EOF

    if [ "$REGISTRY_URL" != "https://index.docker.io/v1" ]; then
        cat >> "$YAML_PATH" <<EOF
    write_files:
      - path: /etc/docker/daemon.json
        permissions: 0644
        owner: root
        content: |
            {
                "registry-mirrors": [
                  "${REGISTRY_URL}"
                ],
                "labels": [
                    "PROJECT_COMMIT=${TARGET_PROJECT_GIT_COMMIT}"
                ]
            }


EOF

    fi

fi

if [ "$VIRTUAL_MACHINE" = base ]; then
    cat >> "$YAML_PATH" <<EOF
    runcmd:
      - sudo mkdir -m 0755 -p /etc/apt/keyrings
      - curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      - echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
      - sudo apt-get update
      - sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      - sudo DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server

EOF

fi

if [ "$VIRTUAL_MACHINE" != base ]; then
    # all other machines that are not the base image
    cat >> "$YAML_PATH" <<EOF
  user.vendor-data: |
    #cloud-config
    apt_mirror: http://us.archive.ubuntu.com/ubuntu/
    package_update: false
    package_upgrade: false
    package_reboot_if_required: false

    preserve_hostname: true
    fqdn: ${FQDN}

    resize_rootfs: false

    disk_setup:
      /dev/sdb:
        table_type: 'gpt'
        layout: true
        overwrite: false

    fs_setup:
      - label: docker-data
        filesystem: 'ext4'
        device: '/dev/sdb1'
        overwrite: false

    mounts:
      - [ sdb, /var/lib/docker ]

    mount_default_fields: [ None, None, "auto", "defaults,nofail", "0", "2" ]

EOF
fi

if [ "$VIRTUAL_MACHINE" != base ]; then
    cat >> "$YAML_PATH" <<EOF
  user.network-config: |
    version: 2
    ethernets:
      enp5s0:
        dhcp4: true
        dhcp4-overrides:
          route-metric: 50
        match:
          macaddress: ${MAC_ADDRESS_TO_PROVISION}
        set-name: enp5s0
EOF
fi

# TODO try to get DHCP working reliably.
if [ "$VIRTUAL_MACHINE" = btcpayserver ]; then
    cat >> "$YAML_PATH" <<EOF
      enp6s0:
        addresses:
          - 10.10.10.66/24

EOF
fi

if [ "$VIRTUAL_MACHINE" = www ]; then
    cat >> "$YAML_PATH" <<EOF
      enp6s0:
        addresses:
          - 10.10.10.65/24

EOF
fi


# All profiles get a root disk and cloud-init config.
cat >> "$YAML_PATH" <<EOF
description: Default incus profile for ${FILENAME}
devices:
  root:
    path: /
    pool: ss-base
    type: disk
  config:
    source: cloud-init:config
    type: disk
EOF

if [ "$VIRTUAL_MACHINE" != base ]; then
    cat >> "$YAML_PATH" <<EOF
  ss-data:
    path: ${REMOTE_DATA_PATH}
    pool: ss-base
    source: ${SSDATA_VOLUME_NAME}
    type: disk
  ss-backup:
    path: ${REMOTE_BACKUP_PATH}
    pool: ss-base
    source: ${BACKUP_VOLUME_NAME}
    type: disk
EOF
fi

# Stub out the network piece for the base image.
if [ "$VIRTUAL_MACHINE" = base ]; then
    cat >> "$YAML_PATH" <<EOF
  enp6s0:
    name: enp6s0
    network: incusbr0
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
EOF

    if [ "$VIRTUAL_MACHINE" = www ] || [ "$VIRTUAL_MACHINE" = btcpayserver ]; then
        cat >> "$YAML_PATH" <<EOF
  enp6s0:
    name: enp6s0
    network: ss-ovn
    type: nic
EOF
    fi

    cat >> "$YAML_PATH" <<EOF
name: ${PRIMARY_DOMAIN}
EOF

fi

if [ "$VIRTUAL_MACHINE" = base ]; then
    if ! incus profile list --format csv --project default | grep -q "$INCUS_HOSTNAME"; then
        incus profile create "$INCUS_HOSTNAME" --project default
    fi

    # configure the profile with our generated cloud-init.yml file.
    incus profile edit "$INCUS_HOSTNAME" --project default < "$YAML_PATH"
else
    if ! incus profile list --format csv | grep -q "$INCUS_HOSTNAME"; then
        incus profile create "$INCUS_HOSTNAME"
    fi

    # configure the profile with our generated cloud-init.yml file.
    incus profile edit "$INCUS_HOSTNAME" < "$YAML_PATH"
fi

