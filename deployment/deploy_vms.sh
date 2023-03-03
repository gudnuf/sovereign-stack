#!/bin/bash

set -exu
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

ssh-keygen -f "$SSH_HOME/known_hosts" -R "$FQDN"

# if the machine doesn't exist, we create it.
if ! lxc list --format csv | grep -q "$LXD_VM_NAME"; then

    # create a base image if needed and instantiate a VM.
    if [ -z "$MAC_ADDRESS_TO_PROVISION" ]; then
        echo "ERROR: You MUST define a MAC Address for all your machines by setting WWW_SERVER_MAC_ADDRESS, BTCPAYSERVER_MAC_ADDRESS in your site definition."
        echo "INFO: IMPORTANT! You MUST have DHCP Reservations for these MAC addresses. You also need records established the DNS."
        exit 1
    fi

    ./stub_lxc_profile.sh "$LXD_VM_NAME"

    lxc copy --profile="$LXD_VM_NAME" "$BASE_IMAGE_VM_NAME"/"ss-docker-$LXD_UBUNTU_BASE_VERSION" "$LXD_VM_NAME"

    # now let's create a new VM to work with.
    #@lxc init --profile="$LXD_VM_NAME" "$BASE_IMAGE_VM_NAME" "$LXD_VM_NAME" --vm

    # let's PIN the HW address for now so we don't exhaust IP
    # and so we can set DNS internally.
    lxc config set "$LXD_VM_NAME" "volatile.enp5s0.hwaddr=$MAC_ADDRESS_TO_PROVISION"
    lxc config device override "$LXD_VM_NAME" root size="${ROOT_DISK_SIZE_GB}GB"

    lxc start "$LXD_VM_NAME"

    bash -c "./wait_for_lxc_ip.sh --lxc-name=$LXD_VM_NAME"
fi

# scan the remote machine and install it's identity in our SSH known_hosts file.
ssh-keyscan -H -t ecdsa "$FQDN" >> "$SSH_HOME/known_hosts"

# create a directory to store backup archives. This is on all new vms.
ssh "$FQDN" mkdir -p "$REMOTE_HOME/backups"
