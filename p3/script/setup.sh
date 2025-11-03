#!/usr/bin/env bash
set -euo pipefail

log() { echo -e "[setup] $*"; }

if ! sudo -l &>'/dev/null'; then

    log 'sudo privileges required'
    exit 1
fi

#============================#
log 'updating packages...'

sudo apt-get update -y

#============================#
if ! command -v 'docker' &>'/dev/null'; then

    sudo apt-get install -y 'ca-certificates'
    sudo apt-get install -y 'curl'

    sudo install -m 0755 -d '/etc/apt/keyrings'

    SRC='https://download.docker.com/linux/debian'
    DST='/etc/apt/keyrings/docker.asc'

    sudo curl -fsSL "$SRC/gpg" -o "$DST"
    sudo chmod a+r "$DST"

    ARCH=$(dpkg --print-architecture)
    CODENAME=$(. '/etc/os-release' && echo "$VERSION_CODENAME")

    ENTRY="deb [arch=$ARCH signed-by=$DST] $SRC $CODENAME stable"
    SOURCE_LIST='/etc/apt/sources.list.d/docker.list'

    echo "$ENTRY" | sudo tee "$SOURCE_LIST" > '/dev/null'
    sudo apt-get update -y

    sudo apt-get install -y 'docker-ce'
    sudo apt-get install -y 'docker-ce-cli'
    sudo apt-get install -y 'containerd.io'
    sudo apt-get install -y 'docker-buildx-plugin'
    sudo apt-get install -y 'docker-compose-plugin'

    sudo usermod -aG 'docker' "$USER"
fi
log 'docker installed'

#============================#
if ! command -v 'kubectl' &>'/dev/null'; then

    VERSION=$(curl -fsSL 'https://dl.k8s.io/release/stable.txt')

    SRC="https://dl.k8s.io/release/${VERSION}/bin/linux/amd64/kubectl"
    DST='/usr/local/bin/kubectl'

    curl -fsSLo 'kubectl' "$SRC"
    sudo install -o 'root' -g 'root' -m '0755' 'kubectl' "$DST"
    rm -f 'kubectl'
fi
log 'kubectl installed'

#============================#
if ! command -v 'k3d' &>'/dev/null'; then

    SRC='https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh'
    curl -s "$SRC" | bash
fi
log 'k3d installed'

#============================#
CLUSTER='iot'

if ! k3d cluster list | grep -q "^${CLUSTER}\s"; then

    PORT='8888:8888@loadbalancer'
    k3d cluster create "$CLUSTER" --agents '1' --port "$PORT"
fi
kubectl wait --for='condition=ready' node --all
log "k3d cluster '${CLUSTER}' ready"

#============================#
DIRNAME="$(dirname "$0")"
BASE_DIR="$(cd "$DIRNAME/.." && pwd)"

ARGOCD_DIR="${BASE_DIR}/k8s/argocd"

if ! kubectl get ns 'argocd' &>'/dev/null'; then

    URL='https://raw.githubusercontent.com/argoproj/argo-cd'
    URL+='/stable/manifests/install.yaml'

    kubectl apply -f "${ARGOCD_DIR}/namespace.yaml"
    kubectl apply -n 'argocd' -f "$URL"
fi
kubectl -n 'argocd' rollout status 'deploy/argocd-server'
kubectl -n 'argocd' rollout status 'deploy/argocd-repo-server'
kubectl -n 'argocd' rollout status 'statefulset/argocd-application-controller'

kubectl apply -f "${ARGOCD_DIR}/application.yaml"
log 'argocd ready'

#============================#
log 'done'
