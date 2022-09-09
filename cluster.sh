#!/bin/bash

set -eux
cd "$(dirname "$0")"

# This script is meant to be executed on the management machine.
# it reaches out to an SSH endpoint and provisions that machine
# to use LXD.

COMMAND="${1:-}"
DATA_PLANE_MACVLAN_INTERFACE=
DISK_TO_USE=loop

if [ "$COMMAND" = create ]; then

    # override the cluster name.
    CLUSTER_NAME="${2:-}"
    

    if [ -z "$CLUSTER_NAME" ]; then
        echo "ERROR: The cluster name was not provided."
        exit 1
    fi

    #shellcheck disable=SC1091
    source ./defaults.sh

    export CLUSTER_PATH="$CLUSTERS_DIR/$CLUSTER_NAME"
    CLUSTER_DEFINITION="$CLUSTER_PATH/cluster_definition"
    export CLUSTER_DEFINITION="$CLUSTER_DEFINITION"

    mkdir -p "$CLUSTER_PATH"
    if [ ! -f "$CLUSTER_DEFINITION" ]; then
        # stub out a cluster_definition.
    cat >"$CLUSTER_DEFINITION" <<EOL
#!/bin/bash

# see https://www.sovereign-stack.org/cluster_definition for more info!

export LXD_CLUSTER_PASSWORD="$(gpg --gen-random --armor 1 14)"
export SOVEREIGN_STACK_MAC_ADDRESS="CHANGE_ME_REQUIRED"
export PROJECT_NAME="$CLUSTER_NAME-public"
export REGISTRY_URL="http://$(hostname).$(resolvectl status | grep 'DNS Domain:' | awk '{ print $3 }'):5000"
export REGISTRY_USERNAME="CHANGE_ME"
export REGISTRY_PASSWORD="CHANGE_ME"

EOL

        chmod 0744 "$CLUSTER_DEFINITION"
        echo "We stubbed out a '$CLUSTER_DEFINITION' file for you."
        echo "Use this file to customize your cluster deployment;"
        echo "Check out 'https://www.sovereign-stack.org/cluster-definition' for an example."
        exit 1
    fi

    source "$CLUSTER_DEFINITION"

    if ! lxc remote list | grep -q "$CLUSTER_NAME"; then
        FQDN="${3:-}"
        shift

        if [ -z "$FQDN" ]; then
            echo "ERROR: The Fully Qualified Domain Name of the new cluster member was not set."
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

        # if [ -z "$DATA_PLANE_MACVLAN_INTERFACE" ]; then
        #     echo "INFO: It looks like you didn't provide input on the command line for the data plane macvlan interface."
        #     echo "      We need to know which interface that is! Enter it here now."
        #     echo ""

        #     ssh "ubuntu@$FQDN" ip link

        #     echo "Please enter the network interface that's dedicated to the Sovereign Stack data plane: "
        #     read -r DATA_PLANE_MACVLAN_INTERFACE

        # fi

        # if [ -z "$DISK_TO_USE" ]; then
        #     echo "INFO: It looks like the DISK_TO_USE has not been set. Enter it now."
        #     echo ""

        #     ssh "ubuntu@$FQDN" lsblk

        #     USER_DISK=
        #     echo "Please enter the disk or partition that Sovereign Stack will use to store data (default: loop):  "
        #     read -r USER_DISK

        # fi

    else
        echo "ERROR: the cluster already exists! You need to go delete your lxd remote if you want to re-create your cluster."
        echo "       It's may also be helpful to reset/rename your cluster path."
        exit 1
    fi

    # ensure we actually have that interface on the system.
    echo "DATA_PLANE_MACVLAN_INTERFACE: $DATA_PLANE_MACVLAN_INTERFACE"
    if ! ssh "ubuntu@$FQDN" ip link | grep "$DATA_PLANE_MACVLAN_INTERFACE" | grep -q ",UP"; then
        echo "ERROR: We could not find your interface in our list of available interfaces. Please run this command again."
        echo "NOTE: You can always specify on the command line by adding the '--data-plane-interface=eth0', for example."
        exit 1
    fi

    # if the disk is loop-based, then we assume the / path exists.
    if [ "$DISK_TO_USE" != loop ]; then
        # ensure we actually have that disk/partition on the system.
        if ssh "ubuntu@$FQDN" lsblk | grep -q "$DISK_TO_USE"; then
            echo "ERROR: We could not the disk you specified. Please run this command again and supply a different disk."
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

    # error out if the cluster password is unset.
    if [ -z "$LXD_CLUSTER_PASSWORD" ]; then
        echo "ERROR: LXD_CLUSTER_PASSWORD must be set in your cluster_definition."
        exit 1
    fi

    if ! command -v lxc >/dev/null 2>&1; then
        if lxc profile list --format csv | grep -q sovereign-stack; then
            lxc profile delete sovereign-stack
            sleep 1
        fi

        if lxc network list --format csv | grep -q lxdbrSS; then
            lxc network delete lxdbrSS
            sleep 1
        fi
    fi

    ssh -t "ubuntu@$FQDN" "
# set host firewall policy. 
# allow LXD API from management network.
# sudo ufw allow from ${IP_OF_MGMT_MACHINE}/32 proto tcp to $MGMT_PLANE_IP port 8443

# enable it.
# if sudo ufw status | grep -q 'Status: inactive'; then
#     sudo ufw enable
# fi

# install lxd as a snap if it's not installed. We only really use the LXC part of this package.
if ! snap list | grep -q lxd; then
    sudo -A snap install lxd
    sleep 4
fi
"
    # if the DATA_PLANE_MACVLAN_INTERFACE is not specified, then we 'll
    # just attach VMs to the network interface used for for the default route.
    if [ -z "$DATA_PLANE_MACVLAN_INTERFACE" ]; then
        DATA_PLANE_MACVLAN_INTERFACE="$(ssh -t ubuntu@"$FQDN" ip route | grep default | cut -d " " -f 5)"
    fi

    # stub out the lxd init file for the remote SSH endpoint.
    CLUSTER_MASTER_LXD_INIT="$CLUSTER_PATH/lxdinit_profile.yml"
    cat >"$CLUSTER_MASTER_LXD_INIT" <<EOF
config:
  core.https_address: ${MGMT_PLANE_IP}:8443
  core.trust_password: ${LXD_CLUSTER_PASSWORD}
  images.auto_update_interval: 15

networks:
- name: lxdbrSS
  type: bridge
  config:
    ipv4.address: 10.139.144.1/24
    ipv4.nat: "false"
    ipv4.dhcp: "false"
    ipv6.address: "none"
    dns.mode: "none"
  #managed: true
  description: ss-config,${DATA_PLANE_MACVLAN_INTERFACE:-},${DISK_TO_USE:-}
  # lxdbrSS is an isolated bridge; no Internet access.

cluster:
  server_name: ${CLUSTER_NAME}
  enabled: true
  member_config: []
  cluster_address: ""
  cluster_certificate: ""
  server_address: ""
  cluster_password: ""
  cluster_certificate_path: ""
  cluster_token: ""
EOF


    # configure the LXD Daemon with our preseed.
    cat "$CLUSTER_MASTER_LXD_INIT" | ssh "ubuntu@$FQDN" lxd init --preseed

    # ensure the lxd service is available over the network, then add a lxc remote, then switch the active remote to it.
    if wait-for-it -t 20 "$FQDN:8443"; then
        # now create a remote on your local LXC client and switch to it.
        # the software will now target the new cluster.
        lxc remote add "$CLUSTER_NAME" "$FQDN" --password="$LXD_CLUSTER_PASSWORD" --protocol=lxd --auth-type=tls --accept-certificate
        lxc remote switch "$CLUSTER_NAME"

        echo "INFO: You have create a new cluster named '$CLUSTER_NAME'. Great! We switched your lxd remote to it."
    else
        echo "ERROR: Could not detect the LXD endpoint. Something went wrong."
        exit 1
    fi

    echo "HINT: Now you can consider running 'ss-deploy'."
else
  echo "ERROR: invalid command."
  exit 1
fi
