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
echo 'Sharing server token...'

SRC='/var/lib/rancher/k3s/server/node-token'
DST='/vagrant/server-token'

while [ ! -f "$SRC" ]; do sleep 1; done

cp "$SRC" "$DST"

#============================#
echo 'K3s server setup complete'
