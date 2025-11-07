#!/usr/bin/env bash
set -euo pipefail

GITLAB_NAMESPACE="$1"
GITLAB_URL="http://$2"
GITLAB_URI="$3"

APP_NAMESPACE="$4"
APP_NAME="$5"

GITLAB_GROUP="${GITLAB_URI%%/*}"
GITLAB_PROJECT="${GITLAB_URI##*/}"

log() { echo -e "[gitlab/switch] $*"; }

#============================# Checks
if ! kubectl get namespace "$GITLAB_NAMESPACE" &>'/dev/null'; then

    log "namespace '$GITLAB_NAMESPACE' not found"
    exit 1
fi
#============================# Update application version
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

GITLAB_PASSWORD="$(
    kubectl -n "$GITLAB_NAMESPACE" \
        get secret 'gitlab-gitlab-initial-root-password' \
        -o jsonpath='{.data.password}' | base64 -d
)"
GITLAB_LOGIN="root:$GITLAB_PASSWORD"

DOMAIN="${GITLAB_URL#*://}"
REPO_URL="http://root:${GITLAB_PASSWORD}@${DOMAIN}/${GITLAB_URI}.git"

DST="$TMP_DIR/clone"
git clone -q "$REPO_URL" "$DST"

pushd "$DST" >'/dev/null'

    FILE='playground/deployment.yaml'
    TAG="$(
        grep -Eo 'wil42/playground:v[0-9]+' "$FILE" \
            | head -n1 \
            | sed -E 's#.*:(v[0-9]+)$#\1#'
    )"
    if [[ "$TAG" == 'v1' ]]; then NEW_TAG='v2'; 
    elif [[ "$TAG" == 'v2' ]]; then NEW_TAG='v1'; 
    else 
        log "invalid current tag '$TAG'"
        exit 1
    fi
    sed -iE "s#wil42/playground:v[0-9]+#wil42/playground:${NEW_TAG}#" "$FILE"

    git config user.name 'root'
    git config user.email 'root@gitlab.local'

    git add "$FILE"
    git commit -qm "switch playground image to ${NEW_TAG}"
    git push -q 'origin' 'main'

popd >'/dev/null'
log "application version switched to '$NEW_TAG'"

#============================# Trigger ArgoCD refresh
kubectl -n "$APP_NAMESPACE" annotate application "$APP_NAME" \
  'argocd.argoproj.io/refresh=hard' --overwrite

#============================#
log 'done'
