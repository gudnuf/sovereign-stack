#!/bin/bash

# The purpose of this script is to use a Docker container to get and build the Clams
# server-side pieces and output them to a specified directory. These files are then 
# ready build to be served by a TLS-enabled reverse proxy. It goes
# Client Browser -> wss (WebSocket over TLS) -> ProxyServer -> TCP to btcpayserver:9735

set -ex
cd "$(dirname "$0")"

export CLAMS_OUTPUT_DIR="$REMOTE_HOME/clams"

ssh "$PRIMARY_WWW_FQDN" sudo rm -rf "$CLAMS_OUTPUT_DIR"
ssh "$PRIMARY_WWW_FQDN" mkdir -p "$CLAMS_OUTPUT_DIR"

if docker ps | grep -q clams; then
    docker kill clams
fi

if docker ps -a | grep -q clams; then
    docker system prune -f
fi

docker build -t clams:latest .

docker run -it --name clams -v "$CLAMS_OUTPUT_DIR":/output clams:latest

ssh "$PRIMARY_WWW_FQDN" sudo chown -R ubuntu:ubuntu "$CLAMS_OUTPUT_DIR"
