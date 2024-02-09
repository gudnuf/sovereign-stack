#!/bin/bash

set -exu
cd "$(dirname "$0")"

# This script is meant to be executed on the management machine.
# it reaches out to an SSH endpoint and provisions that machine
# to use incus.

DATA_PLANE_MACVLAN_INTERFACE=
DISK_TO_USE=

# override the remote name.
REMOTE_NAME="${1:-}"
if [ -z "$REMOTE_NAME" ]; then
    echo "ERROR: The remote name was not provided. Syntax is: 'ss-remote <remote_name> <remote01.domain.tld>'"
    echo "  for example: 'ss-remote development clusterhost00.domain.tld"
    exit 1
fi

. ./deployment_defaults.sh

. ./base.sh

export REMOTE_PATH="$REMOTES_PATH/$REMOTE_NAME"
REMOTE_DEFINITION="$REMOTE_PATH/remote.conf"
export REMOTE_DEFINITION="$REMOTE_DEFINITION"

mkdir -p "$REMOTE_PATH"
if [ ! -f "$REMOTE_DEFINITION" ]; then
    # stub out a remote.conf.
    cat >"$REMOTE_DEFINITION" <<EOL
# https://www.sovereign-stack.org/ss-remote

# REGISTRY_URL=http://registry.domain.tld:5000

EOL

    chmod 0744 "$REMOTE_DEFINITION"
    echo "We stubbed out a '$REMOTE_DEFINITION' file for you."
    echo "Use this file to customize your remote deployment;"
    echo "Check out 'https://www.sovereign-stack.org/ss-remote' for more information."
    exit 1
fi

source "$REMOTE_DEFINITION"

if ! incus remote list | grep -q "$REMOTE_NAME"; then
    FQDN="${2:-}"

    if [ -z "$FQDN" ]; then
        echo "ERROR: You MUST provide the FQDN of the remote host."
        exit
    fi

    shift

    if [ -z "$FQDN" ]; then
        echo "ERROR: The Fully Qualified Domain Name of the new remote member was not set."
        exit 1
    fi

    # let's check to ensure we have SSH access to the specified host.
    if ! wait-for-it -t 5 "$FQDN:22"; then
        echo "ERROR: We can't get an SSH connection to '$FQDN:22'. Ensure you have the host set up correctly."
        exit 1
    fi

    # grab any modifications from the command line.
    for i in "$@"; do
        case $i in
            --data-plane-interface=*)
                DATA_PLANE_MACVLAN_INTERFACE="${i#*=}"
                shift
            ;;
            --disk=*)
                DISK_TO_USE="${i#*=}"
                shift
            ;;
            *)

            ;;
        esac
    done

    # first let's copy our ssh pubkey to the remote server so we don't have to login constantly.
    ssh-copy-id -i "$HOME/.ssh/id_rsa.pub" "ubuntu@$FQDN"

    if [ -z "$DISK_TO_USE" ]; then
        if ! ssh "ubuntu@$FQDN" incus storage list -q | grep -q ss-base; then
            echo "INFO: It looks like the DISK_TO_USE has not been set. Enter it now."
            echo ""

            ssh "ubuntu@$FQDN" lsblk --paths

            echo "Please enter the disk or partition that Sovereign Stack will use to store data:  "
            read -r DISK_TO_USE
        fi
    fi

else
    echo "ERROR: the remote already exists! You need to go delete your incus remote if you want to re-create your remote."
    echo "       It's may also be helpful to reset/rename your remote path."
    exit 1
fi


#ssh "ubuntu@$FQDN" 'sudo echo "ubuntu ALL=(ALL) NOPASSWD: /bin/su - a" >> /etc/sudoers'

# if the disk is loop-based, then we assume the / path exists.
if [ "$DISK_TO_USE" != loop ]; then
    # ensure we actually have that disk/partition on the system.
    if ! ssh "ubuntu@$FQDN" lsblk --paths | grep -q "$DISK_TO_USE"; then
        echo "ERROR: We could not findthe disk you specified. Please run this command again and supply a different disk."
        echo "NOTE: You can always specify on the command line by adding the '--disk=/dev/sdd', for example."
        exit 1
    fi
fi

if ! command -v incus >/dev/null 2>&1; then
    if incus profile list --format csv | grep -q "$BASE_IMAGE_VM_NAME"; then
        incus profile delete "$BASE_IMAGE_VM_NAME"
        sleep 1
    fi

    if incus network list --format csv -q --project default | grep -q incusbr0; then
        incus network delete incusbr0 --project default
        sleep 1
    fi


    if incus network list --format csv -q project default | grep -q incusbr1; then
        incus network delete incusbr1 --project default
        sleep 1
    fi

fi

# install dependencies.
ssh -t "ubuntu@$FQDN" 'sudo apt update && sudo apt upgrade -y && sudo apt install htop dnsutils nano zfsutils-linux -y'

REMOTE_SCRIPT_PATH="$REMOTE_HOME/install_incus.sh"
scp ../install_incus.sh "ubuntu@$FQDN:$REMOTE_SCRIPT_PATH"
ssh -t "ubuntu@$FQDN" "chmod +x $REMOTE_SCRIPT_PATH"
ssh -t "ubuntu@$FQDN" "sudo bash -c $REMOTE_SCRIPT_PATH"
ssh -t "ubuntu@$FQDN" "sudo adduser ubuntu incus-admin"

# install OVN for the project-specific bridge networks
ssh -t "ubuntu@$FQDN" "sudo apt-get install -y ovn-host ovn-central && sudo ovs-vsctl set open_vswitch . external_ids:ovn-remote=unix:/var/run/ovn/ovnsb_db.sock external_ids:ovn-encap-type=geneve external_ids:ovn-encap-ip=127.0.0.1"

# if the user did not specify the interface, we just use whatever is used for the default route.
if [ -z "$DATA_PLANE_MACVLAN_INTERFACE" ]; then
    DATA_PLANE_MACVLAN_INTERFACE="$(ssh ubuntu@"$FQDN" ip route | grep "default via" | awk '{print $5}')"
fi

export DATA_PLANE_MACVLAN_INTERFACE="$DATA_PLANE_MACVLAN_INTERFACE"

MGMT_PLANE_IP="$(ssh ubuntu@"$FQDN" env | grep SSH_CONNECTION | cut -d " " -f 3)"
IP_OF_MGMT_MACHINE="$(ssh ubuntu@"$FQDN" env | grep SSH_CLIENT | cut -d " " -f 1 )"
IP_OF_MGMT_MACHINE="${IP_OF_MGMT_MACHINE#*=}"
IP_OF_MGMT_MACHINE="$(echo "$IP_OF_MGMT_MACHINE" | cut -d: -f1)"

# run incus admin init on the remote server.
cat <<EOF | ssh ubuntu@"$FQDN" incus admin init --preseed
config:
  core.https_address: ${MGMT_PLANE_IP}:8443
  core.dns_address: ${MGMT_PLANE_IP}
  images.auto_update_interval: 15
  
networks:
- name: incusbr0
  description: "ss-config,${DATA_PLANE_MACVLAN_INTERFACE:-error}"
  type: bridge
  config:
    ipv4.address: 10.9.9.1/24
    ipv4.dhcp.ranges: 10.9.9.10-10.9.9.127
    ipv4.nat: true
    ipv6.address: none
    dns.mode: managed
- name: incusbr1
  description: "Non-natting bridge needed for ovn networks."
  type: bridge
  config:
    ipv4.address: 10.10.10.1/24
    ipv4.dhcp.ranges: 10.10.10.10-10.10.10.63
    ipv4.ovn.ranges: 10.10.10.64-10.10.10.254
    ipv4.nat: false
    ipv6.address: none
profiles:
- config: {}
  description: "default profile for sovereign-stack instances."
  devices:
    root:
      path: /
      pool: ss-base
      type: disk
  name: default
EOF

ssh ubuntu@"$FQDN" incus project list -q >> /dev/null

# ensure the incus service is available over the network, then add a incus remote, then switch the active remote to it.
if wait-for-it -t 20 "$FQDN:8443"; then
    # before we add the remote, we need a trust token from the incus server
    INCUS_CERT_TRUST_TOKEN=$(ssh ubuntu@"$FQDN" incus config trust add ss-mgmt | tail -n 1)

    # now create a remote on your local incus client and switch to it.
    # the software will now target the new remote.
    incus remote add "$REMOTE_NAME" "$FQDN" --auth-type=tls --accept-certificate --token="$INCUS_CERT_TRUST_TOKEN"
    incus remote switch "$REMOTE_NAME"

    echo "INFO: A new remote named '$REMOTE_NAME' has been created. Your incus client has been switched to it."
else
    echo "ERROR: Could not detect the incus endpoint. Something went wrong."
    exit 1
fi

# create the default storage pool if necessary
if ! incus storage list --format csv | grep -q ss-base; then

    if [ "$DISK_TO_USE" != loop ]; then
        # we omit putting a size here so, so incus will consume the entire disk if '/dev/sdb' or partition if '/dev/sdb1'.
        # TODO do some sanity/resource checking on DISK_TO_USE. Impelment full-disk encryption?
        incus storage create ss-base zfs source="$DISK_TO_USE"
    else
        # if a disk is the default 'loop', then we create a zfs storage pool 
        # on top of the existing filesystem using a loop device, per incus docs
        incus storage create ss-base zfs
    fi

    # # create the testnet/mainnet blocks/chainstate subvolumes.
    # for CHAIN in mainnet testnet; do
    #     for DATA in blocks chainstate; do
    #         if ! incus storage volume list ss-base | grep -q "$CHAIN-$DATA"; then
    #             incus storage volume create ss-base "$CHAIN-$DATA" --type=filesystem
    #         fi
    #     done
    # done

fi

echo "INFO: completed remote.sh."
