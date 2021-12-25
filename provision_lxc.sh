#!/bin/bash

set -eu

# check to ensure the admin has specified a MACVLAN interface
if [ -z "$DEV_MACVLAN_INTERFACE" ]; then
    echo "ERROR: DEV_MACVLAN_INTERFACE not defined in project."
    exit 1
fi

# The base VM image.
BASE_LXC_IMAGE="ubuntu/21.04/cloud"

# let's create a profile for the BCM TYPE-1 VMs. This is per VM.
if ! lxc profile list --format csv | grep -q "$LXD_VM_NAME"; then
    lxc profile create "$LXD_VM_NAME"
fi

# generate the custom cloud-init file. Cloud init installs and configures sshd
SSH_AUTHORIZED_KEY=$(<"$SSH_HOME/id_rsa.pub")
eval "$(ssh-agent -s)"
ssh-add "$SSH_HOME/id_rsa"
export SSH_AUTHORIZED_KEY="$SSH_AUTHORIZED_KEY"
envsubst < ./lxc_profile.yml > "$SITE_PATH/cloud-init.yml"

# configure the profile with our generated cloud-init.yml file.
cat "$SITE_PATH/cloud-init.yml" | lxc profile edit "$LXD_VM_NAME"

wait_for_lxc_ip () {

LXC_INSTANCE_NAME="$1"
IP_V4_ADDRESS=
while true; do
    IP_V4_ADDRESS="$(lxc list "$LXC_INSTANCE_NAME" --format csv --columns=4 | grep enp5s0 | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')" || true
    if [ -n "$IP_V4_ADDRESS" ]; then
        # give the machine extra time to spin up.
        wait-for-it -t 300 "$IP_V4_ADDRESS:22"
        break
    else
        sleep 1
        printf '.'
    fi
done

}


# create the default storage pool if necessary
if ! lxc storage list --format csv | grep -q default; then
    if [ -n "$LXD_DISK_TO_USE" ]; then
        lxc storage create default zfs source="$LXD_DISK_TO_USE" size="${ROOT_DISK_SIZE_GB}GB"
    else
        lxc storage create default zfs size="${ROOT_DISK_SIZE_GB}GB"
    fi
fi


MAC_ADDRESS_TO_PROVISION="$DEV_WWW_MAC_ADDRESS"
if [ "$APP_TO_DEPLOY" = btcpay ]; then
    MAC_ADDRESS_TO_PROVISION="$DEV_BTCPAY_MAC_ADDRESS"
fi

# If our template doesn't exist, we create one.
if ! lxc image list --format csv "$VM_NAME" | grep -q "$VM_NAME"; then
    
    # If the lxc VM does exist, then we will delete it (so we can start fresh) 
    if lxc list -q --format csv | grep -q "$VM_NAME"; then
        lxc delete "$VM_NAME" --force

        # remove the ssh known endpoint else we get warnings.
        ssh-keygen -f "$SSH_HOME/known_hosts" -R "$VM_NAME"
    fi

    # let's download our base image.
    if ! lxc image list --format csv --columns l | grep -q "ubuntu-21-04"; then
        # if the image doesn't exist, download it from Ubuntu's image server
        # TODO see if we can fetch this file from a more censorship-resistant source, e.g., ipfs
        # we don't really need to cache this locally since it gets continually updated upstream.
        lxc image copy "images:$BASE_LXC_IMAGE" "$DEV_LXD_REMOTE": --alias "ubuntu-21-04" --public --vm
    fi

    lxc init \
        --profile="sovereign-stack" \
        "ubuntu-21-04" \
        "$VM_NAME" --vm

    # let's PIN the HW address for now so we don't exhaust IP
    # and so we can set DNS internally.
    lxc config set "$VM_NAME" "volatile.enp5s0.hwaddr=$MAC_ADDRESS_TO_PROVISION"

    lxc start "$VM_NAME"

    # let's wait a minimum of 15 seconds before we start checking for an IP address.
    sleep 15

    # let's wait for the LXC vm remote machine to get an IP address.
    wait_for_lxc_ip "$VM_NAME"

    # Let's remove any entry in our known_hosts, then add it back.
    # we are using IP address here so we don't have to rely on external DNS 
    # configuration for the base image preparataion.
    ssh-keygen -R "$IP_V4_ADDRESS"
    ssh-keyscan -H -t ecdsa "$IP_V4_ADDRESS" >> "$SSH_HOME/known_hosts"
    ssh "ubuntu@$IP_V4_ADDRESS" sudo chown -R ubuntu:ubuntu "$REMOTE_HOME"
    
    # stop the VM and get a snapshot.
    lxc stop "$VM_NAME"
    lxc publish "$DEV_LXD_REMOTE:$VM_NAME" --alias "$VM_NAME" --public
    lxc delete "$VM_NAME"
fi

# now let's create a new VM to work with.
lxc init --profile="sovereign-stack" "$VM_NAME" "$LXD_VM_NAME" --vm

# let's PIN the HW address for now so we don't exhaust IP
# and so we can set DNS internally.
lxc config set "$LXD_VM_NAME" "volatile.enp5s0.hwaddr=$MAC_ADDRESS_TO_PROVISION"
lxc config device override "$LXD_VM_NAME" root size="${ROOT_DISK_SIZE_GB}GB"

lxc start "$LXD_VM_NAME"

wait_for_lxc_ip "$LXD_VM_NAME"

# remove any existing SSH identities for the host, then add it back.
ssh-keygen -R "$IP_V4_ADDRESS"