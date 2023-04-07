#!/bin/bash

set -eu
cd "$(dirname "$0")"

## This is a weird if clause since we need to LEFT-ALIGN the statement below.
SSH_STRING="Host ${FQDN}"
if ! grep -q "$SSH_STRING" "$SSH_HOME/config"; then

########## BEGIN
cat >> "$SSH_HOME/config" <<-EOF

${SSH_STRING}
    HostName ${FQDN}
    User ubuntu
EOF
###

fi

# if the machine doesn't exist, we create it.
if ! lxc list --format csv | grep -q "$LXD_VM_NAME"; then

    # create a base image if needed and instantiate a VM.
    if [ -z "$MAC_ADDRESS_TO_PROVISION" ]; then
        echo "ERROR: You MUST define a MAC Address for all your machines by setting WWW_SERVER_MAC_ADDRESS, BTCPAYSERVER_MAC_ADDRESS in your site definition."
        echo "INFO: IMPORTANT! You MUST have DHCP Reservations for these MAC addresses. You also need records established the DNS."
        exit 1
    fi

    # TODO ensure we are only GROWING the volume--never shrinking per zfs volume docs.
    VM_ID=
    BACKUP_DISK_SIZE_GB=
    SSDATA_DISK_SIZE_GB=
    DOCKER_DISK_SIZE_GB=
    if [ "$VIRTUAL_MACHINE" = www ]; then
        VM_ID="w"
        BACKUP_DISK_SIZE_GB="$WWW_BACKUP_DISK_SIZE_GB"
        SSDATA_DISK_SIZE_GB="$WWW_SSDATA_DISK_SIZE_GB"
        DOCKER_DISK_SIZE_GB="$WWW_DOCKER_DISK_SIZE_GB"
    fi

    if [ "$VIRTUAL_MACHINE" = btcpayserver ]; then
        VM_ID="b"
        BACKUP_DISK_SIZE_GB="$BTCPAYSERVER_BACKUP_DISK_SIZE_GB"
        SSDATA_DISK_SIZE_GB="$BTCPAYSERVER_SSDATA_DISK_SIZE_GB"
        DOCKER_DISK_SIZE_GB="$BTCPAYSERVER_DOCKER_DISK_SIZE_GB"
    fi
    
    DOCKER_VOLUME_NAME="$PRIMARY_DOMAIN_IDENTIFIER-$VM_ID""d"
    if ! lxc storage volume list ss-base | grep -q "$DOCKER_VOLUME_NAME"; then
        lxc storage volume create ss-base "$DOCKER_VOLUME_NAME" --type=block
    fi

    # TODO ensure we are only GROWING the volume--never shrinking
    lxc storage volume set ss-base "$DOCKER_VOLUME_NAME" size="${DOCKER_DISK_SIZE_GB}GB"

    SSDATA_VOLUME_NAME="$PRIMARY_DOMAIN_IDENTIFIER-$VM_ID""s"
    if ! lxc storage volume list ss-base | grep -q "$SSDATA_VOLUME_NAME"; then
        lxc storage volume create ss-base "$SSDATA_VOLUME_NAME" --type=filesystem
    fi

    # TODO ensure we are only GROWING the volume--never shrinking per zfs volume docs.
    lxc storage volume set ss-base "$SSDATA_VOLUME_NAME" size="${SSDATA_DISK_SIZE_GB}GB"


    BACKUP_VOLUME_NAME="$PRIMARY_DOMAIN_IDENTIFIER-$VM_ID""b"
    if ! lxc storage volume list ss-base | grep -q "$BACKUP_VOLUME_NAME"; then
        lxc storage volume create ss-base "$BACKUP_VOLUME_NAME" --type=filesystem
    fi

    lxc storage volume set ss-base "$BACKUP_VOLUME_NAME" size="${BACKUP_DISK_SIZE_GB}GB"


    bash -c "./stub_lxc_profile.sh --vm=$VIRTUAL_MACHINE --lxd-hostname=$LXD_VM_NAME --ss-volume-name=$SSDATA_VOLUME_NAME --backup-volume-name=$BACKUP_VOLUME_NAME"

    # now let's create a new VM to work with.
    #lxc init --profile="$LXD_VM_NAME" "$BASE_IMAGE_VM_NAME" "$LXD_VM_NAME" --vm
    lxc init "$DOCKER_BASE_IMAGE_NAME" "$LXD_VM_NAME" --vm --profile="$LXD_VM_NAME"

    # let's PIN the HW address for now so we don't exhaust IP
    # and so we can set DNS internally.
    lxc config set "$LXD_VM_NAME" "volatile.enp5s0.hwaddr=$MAC_ADDRESS_TO_PROVISION"

    # attack the docker block device.
    lxc storage volume attach ss-base "$DOCKER_VOLUME_NAME" "$LXD_VM_NAME"

    # if [ "$VIRTUAL_MACHINE" = btcpayserver ]; then
    #     # attach any volumes
    #     for CHAIN in testnet mainnet; do
    #         for DATA in blocks chainstate; do
    #             MOUNT_PATH="/$CHAIN-$DATA"
    #             lxc config device add "$LXD_VM_NAME" "$CHAIN-$DATA" disk pool=ss-base source="$CHAIN-$DATA" path="$MOUNT_PATH"
    #         done
    #     done
    # fi

    lxc start "$LXD_VM_NAME"
    sleep 10

    bash -c "./wait_for_lxc_ip.sh --lxd-name=$LXD_VM_NAME"

    # scan the remote machine and install it's identity in our SSH known_hosts file.
    ssh-keyscan -H -t ecdsa "$FQDN" >> "$SSH_HOME/known_hosts"

    ssh "$FQDN" "sudo chown ubuntu:ubuntu $REMOTE_DATA_PATH"
    ssh "$FQDN" "sudo chown -R ubuntu:ubuntu $REMOTE_BACKUP_PATH"

fi