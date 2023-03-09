#!/bin/bash

set -e
cd "$(dirname "$0")"

# This script is meant to be executed on the management machine.
# it reaches out to an SSH endpoint and provisions that machine
# to use LXD.

DATA_PLANE_MACVLAN_INTERFACE=
DISK_TO_USE=

# override the remote name.
REMOTE_NAME="${1:-}"
if [ -z "$REMOTE_NAME" ]; then
    echo "ERROR: The remote name was not provided. Syntax is: 'ss-remote REMOTE_NAME SSH_HOST_FQDN'"
    echo "  for example: 'ss-remote dev host01.domain.tld"
    exit 1
fi

#shellcheck disable=SC1091
source ../defaults.sh

export REMOTE_PATH="$REMOTES_DIR/$REMOTE_NAME"
REMOTE_DEFINITION="$REMOTE_PATH/remote_definition"
export REMOTE_DEFINITION="$REMOTE_DEFINITION"

mkdir -p "$REMOTE_PATH"
if [ ! -f "$REMOTE_DEFINITION" ]; then
    # stub out a remote_definition.
    cat >"$REMOTE_DEFINITION" <<EOL
#!/bin/bash

# see https://www.sovereign-stack.org/remote for more info!

export LXD_REMOTE_PASSWORD="$(gpg --gen-random --armor 1 14)"
export BITCOIN_CHAIN="regtest"
export PROJECT_PREFIX="$REMOTE_NAME"
#export REGISTRY_URL=http://registry.domain.tld:5000

EOL

    chmod 0744 "$REMOTE_DEFINITION"
    echo "We stubbed out a '$REMOTE_DEFINITION' file for you."
    echo "Use this file to customize your remote deployment;"
    echo "Check out 'https://www.sovereign-stack.org/remote' for more information."
    exit 1
fi

source "$REMOTE_DEFINITION"

if ! lxc remote list | grep -q "$REMOTE_NAME"; then
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

    if [ -z "$DATA_PLANE_MACVLAN_INTERFACE" ]; then
        echo "INFO: It looks like you didn't provide input on the command line for the data plane macvlan interface."
        echo "      We need to know which interface that is! Enter it here now."
        echo ""

        ssh "ubuntu@$FQDN" ip link

        echo "Please enter the network interface that's dedicated to the Sovereign Stack data plane: "
        read -r DATA_PLANE_MACVLAN_INTERFACE

    fi

    if [ -z "$DISK_TO_USE" ]; then
        echo "INFO: It looks like the DISK_TO_USE has not been set. Enter it now."
        echo ""

        ssh "ubuntu@$FQDN" lsblk --paths

        echo "Please enter the disk or partition that Sovereign Stack will use to store data (default: loop):  "
        read -r DISK_TO_USE
    fi

else
    echo "ERROR: the remote already exists! You need to go delete your lxd remote if you want to re-create your remote."
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

# The MGMT Plane IP is the IP address that the LXD API binds to, which happens
# to be the same as whichever SSH connection you're coming in on.
MGMT_PLANE_IP="$(ssh ubuntu@"$FQDN" env | grep SSH_CONNECTION | cut -d " " -f 3)"
IP_OF_MGMT_MACHINE="$(ssh ubuntu@"$FQDN" env | grep SSH_CLIENT | cut -d " " -f 1 )"
IP_OF_MGMT_MACHINE="${IP_OF_MGMT_MACHINE#*=}"
IP_OF_MGMT_MACHINE="$(echo "$IP_OF_MGMT_MACHINE" | cut -d: -f1)"

# error out if the remote password is unset.
if [ -z "$LXD_REMOTE_PASSWORD" ]; then
    echo "ERROR: LXD_REMOTE_PASSWORD must be set in your remote_definition."
    exit 1
fi

if ! command -v lxc >/dev/null 2>&1; then
    if lxc profile list --format csv | grep -q "$BASE_IMAGE_VM_NAME"; then
        lxc profile delete "$BASE_IMAGE_VM_NAME"
        sleep 1
    fi

    if lxc network list --format csv | grep -q lxdbr0; then
        lxc network delete lxdbr0
        sleep 1
    fi


    if lxc network list --format csv | grep -q lxdbr1; then
        lxc network delete lxdbr1
        sleep 1
    fi

fi

# install dependencies.
ssh -t "ubuntu@$FQDN" 'sudo apt update && sudo apt upgrade -y && sudo apt install htop dnsutils nano -y'
if ! ssh "ubuntu@$FQDN" snap list | grep -q lxd; then
    ssh -t "ubuntu@$FQDN" 'sudo snap install lxd --channel=5.11/stable'
    sleep 5
fi

# install OVN for the project-specific bridge networks
ssh -t "ubuntu@$FQDN" "sudo apt-get install -y ovn-host ovn-central"

ssh -t "ubuntu@$FQDN" "sudo ovs-vsctl set open_vswitch . external_ids:ovn-remote=unix:/var/run/ovn/ovnsb_db.sock external_ids:ovn-encap-type=geneve external_ids:ovn-encap-ip=127.0.0.1"

# if the DATA_PLANE_MACVLAN_INTERFACE is not specified, then we 'll
# just attach VMs to the network interface used for for the default route.
if [ -z "$DATA_PLANE_MACVLAN_INTERFACE" ]; then
    DATA_PLANE_MACVLAN_INTERFACE="$(ssh -t ubuntu@"$FQDN" ip route | grep default | cut -d " " -f 5)"
fi

export DATA_PLANE_MACVLAN_INTERFACE="$DATA_PLANE_MACVLAN_INTERFACE"

# run lxd init on the remote server.
cat <<EOF | ssh ubuntu@"$FQDN" lxd init --preseed
config:
  core.https_address: ${MGMT_PLANE_IP}:8443
  core.trust_password: ${LXD_REMOTE_PASSWORD}
  core.dns_address: ${MGMT_PLANE_IP}
  images.auto_update_interval: 15
  
networks:
- name: lxdbr0
  description: "ss-config,${DATA_PLANE_MACVLAN_INTERFACE:-error}"
  type: bridge
  config:
    ipv4.address: 10.9.9.1/24
    ipv4.dhcp.ranges: 10.9.9.10-10.9.9.127
    ipv4.nat: true
    ipv6.address: none
    dns.mode: managed
- name: lxdbr1
  description: "Non-natting bridge for ovn networks to connect to."
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
cluster:
  server_name: ${REMOTE_NAME}
  enabled: true
  member_config: []
  cluster_address: ""
  cluster_certificate: ""
  server_address: ""
  cluster_password: ""
  cluster_certificate_path: ""
  cluster_token: ""
EOF

# ensure the lxd service is available over the network, then add a lxc remote, then switch the active remote to it.
if wait-for-it -t 20 "$FQDN:8443"; then
    # now create a remote on your local LXC client and switch to it.
    # the software will now target the new remote.
    lxc remote add "$REMOTE_NAME" "$FQDN" --password="$LXD_REMOTE_PASSWORD" --protocol=lxd --auth-type=tls --accept-certificate
    lxc remote switch "$REMOTE_NAME"

    echo "INFO: You have create a new remote named '$REMOTE_NAME'. Great! We switched your lxd remote to it."
else
    echo "ERROR: Could not detect the LXD endpoint. Something went wrong."
    exit 1
fi

# create the default storage pool if necessary
if ! lxc storage list --format csv | grep -q ss-base; then

    if [ "$DISK_TO_USE" != loop ]; then
        # we omit putting a size here so, so LXD will consume the entire disk if '/dev/sdb' or partition if '/dev/sdb1'.
        # TODO do some sanity/resource checking on DISK_TO_USE. Impelment full-disk encryption?
        lxc storage create ss-base zfs source="$DISK_TO_USE"
    else
        # if a disk is the default 'loop', then we create a zfs storage pool 
        # on top of the existing filesystem using a loop device, per LXD docs
        lxc storage create ss-base zfs
    fi
fi