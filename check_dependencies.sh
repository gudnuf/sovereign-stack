#!/bin/bash

set -eu
cd "$(dirname "$0")"


check_dependencies () {
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "This script requires \"${cmd}\" to be installed. Please run 'install.sh'."
      exit 1
    fi
  done
}

# Check system's dependencies
check_dependencies wait-for-it dig rsync sshfs lxc

# let's check to ensure the management machine is on the Baseline ubuntu 21.04
if ! lsb_release -d | grep -q "Ubuntu 22.04"; then
    echo "ERROR: Your machine is not running the Ubuntu 22.04 LTS baseline OS on your management machine."
    exit 1
fi
