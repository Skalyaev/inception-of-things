#!/usr/bin/env bash
set -euo pipefail

SERVER_IP=$1

#============================#
echo 'Installing K3s server...'

AWK='$0 ~ ip {print $2; exit}'
IFACE=$(ip -o addr show | awk -v ip="$SERVER_IP" "$AWK")

export INSTALL_K3S_EXEC="server --flannel-iface=$IFACE"
export K3S_KUBECONFIG_MODE='644'

curl -sfL 'https://get.k3s.io' | sh -

#============================#
echo 'Waiting for K3s server...'

PING_URL="https://127.0.0.1:6443/ping"

until curl -k -s "$PING_URL" | grep -q 'pong'; do
    sleep 1
done

#============================#
echo 'K3s server setup complete'
