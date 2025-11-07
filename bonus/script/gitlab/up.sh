#!/usr/bin/env bash
set -euo pipefail

GITLAB_NAMESPACE="$1"
GITLAB_URL="http://$2"
GITLAB_URI="$3"

GITLAB_GROUP="${GITLAB_URI%%/*}"
GITLAB_PROJECT="${GITLAB_URI##*/}"

DIRNAME="$(dirname "$0")"
BASE_DIR="$(cd "$DIRNAME/../.." && pwd)"

log() { echo -e "[gitlab/up] $*"; }
post() {

    local url="$1"
    local data="$2"
    local token="$3"

    curl -fsS \
        -H 'Content-Type: application/json' \
        -H "PRIVATE-TOKEN: $token" \
        -X 'POST' -d "$data" "$url"
}
extract() {

    local json="$1"
    local to_sed='s/.*"id"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p'

    printf '%s' "$json" | sed -n "$to_sed" | head -n1
}
#============================# Checks
if ! kubectl get namespace "$GITLAB_NAMESPACE" &>'/dev/null'; then

    log "namespace '$GITLAB_NAMESPACE' not found"
    exit 1
fi
#============================# Personal Access Token generation
kubectl -n "$GITLAB_NAMESPACE" rollout status 'deploy/gitlab-toolbox'

QUERY="gitlab-rails runner \"require 'securerandom';"
QUERY+=" u = User.find_by_username('root');"

QUERY+=" t = PersonalAccessToken.new("
QUERY+="name: 'automation',"
QUERY+=" scopes: ['api'],"
QUERY+=" user: u,"
QUERY+=" expires_at: 30.days.from_now);"

QUERY+=" raw = SecureRandom.hex(20);"
QUERY+=" t.set_token(raw); t.save!; puts raw\""

TOKEN="$(
    kubectl -n "$GITLAB_NAMESPACE" exec 'deploy/gitlab-toolbox' \
        -- bash -lc "$QUERY" 2>'/dev/null'
)"
if [[ -z "$TOKEN" ]]; then

    log "failed to generate personal access token"
    exit 1
fi
log "personal access token generated"

#============================# Group creation
URL="$GITLAB_URL/api/v4/groups/$GITLAB_GROUP"

JSON="$(curl -sS -H "PRIVATE-TOKEN: $TOKEN" "$URL")"
GROUP_ID="$(extract "$JSON")"

if [[ -z "$GROUP_ID" ]]; then

    URL="$GITLAB_URL/api/v4/groups"

    DATA="{\"name\":\"$GITLAB_GROUP\""
    DATA+=",\"path\":\"$GITLAB_GROUP\""
    DATA+=",\"visibility\":\"public\"}"

    JSON="$(post "$URL" "$DATA" "$TOKEN")"
    GROUP_ID="$(extract "$JSON")"
fi
if [[ -z "$GROUP_ID" ]]; then

    log "failed to create group '$GITLAB_GROUP'"
    exit 1
fi
log "group created"

#============================# Project creation
URL="$(echo -n "$GITLAB_GROUP/$GITLAB_PROJECT" | sed 's,/,\%2F,g')"
URL="$GITLAB_URL/api/v4/projects/$URL"

JSON="$(curl -sS -H "PRIVATE-TOKEN: $TOKEN" "$URL")"
PROJECT_ID="$(extract "$JSON")"

if [[ -z "$PROJECT_ID" ]]; then

    URL="$GITLAB_URL/api/v4/projects"

    DATA="{\"name\":\"$GITLAB_PROJECT\""
    DATA+=",\"namespace_id\":$GROUP_ID"
    DATA+=",\"visibility\":\"public\"}"

    JSON="$(post "$URL" "$DATA" "$TOKEN")"
    PROJECT_ID="$(extract "$JSON")"
fi
if [[ -z "$PROJECT_ID" ]]; then

    log "failed to create project '$GITLAB_URI'"
    exit 1
fi
log "project created"

#============================# Application upload
DEV_DIR="$BASE_DIR/k8s/dev"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

cp -a "${DEV_DIR}/." "$TMP_DIR/"

GITLAB_PASSWORD="$(
    kubectl -n "$GITLAB_NAMESPACE" \
        get secret 'gitlab-gitlab-initial-root-password' \
        -o jsonpath='{.data.password}' | base64 -d
)"
GITLAB_LOGIN="root:$GITLAB_PASSWORD"

DOMAIN="${GITLAB_URL#*://}"
URL="http://$GITLAB_LOGIN@$DOMAIN/$GITLAB_URI.git"

pushd "$TMP_DIR" >'/dev/null'

    git init -q
    git checkout -b 'main'

    git config user.name 'root'
    git config user.email 'root@gitlab.local'

    git add .
    git commit -qm 'initial commit'

    git remote add 'origin' "$URL"
    git push -u 'origin' 'main' -f

popd >'/dev/null'
log "application uploaded"

#============================#
log 'done'
