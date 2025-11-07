#!/usr/bin/env bash
set -euo pipefail

GITLAB_NAMESPACE="$1"
GITLAB_URL="http://$2"
GITLAB_URI="$3"

GITLAB_GROUP="${GITLAB_URI%%/*}"
GITLAB_PROJECT="${GITLAB_URI##*/}"

log() { echo -e "[gitlab/down] $*"; }
delete() {

    local url="$1"
    local token="$2"

    curl -fsS -H "PRIVATE-TOKEN: $token" -X 'DELETE' "$url"
}
extract() {

    local json="$1"
    local to_sed='s/.*"id"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p'

    printf '%s' "$json" | sed -n "$to_sed" | head -n1
}
#============================# Checks
if ! kubectl get namespace "$GITLAB_NAMESPACE" &>'/dev/null'; then

    log "namespace '$GITLAB_NAMESPACE' not found"
    exit 0
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

#============================# Project deletion
URL="$(echo -n "$GITLAB_GROUP/$GITLAB_PROJECT" | sed 's,/,\%2F,g')"
URL="$GITLAB_URL/api/v4/projects/$URL"

JSON="$(curl -sS -H "PRIVATE-TOKEN: $TOKEN" "$URL")"
PROJECT_ID="$(extract "$JSON")"

if [[ -z "$PROJECT_ID" ]]; then

    log "project '$GITLAB_PROJECT' not found"
    exit 0
fi
delete "$GITLAB_URL/api/v4/projects/$PROJECT_ID" "$TOKEN"
log "project '$GITLAB_PROJECT' deleted"

#============================# Group deletion
URL="$GITLAB_URL/api/v4/groups/$GITLAB_GROUP"

JSON="$(curl -sS -H "PRIVATE-TOKEN: $TOKEN" "$URL")"
GROUP_ID="$(extract "$JSON")"

if [[ -z "$GROUP_ID" ]]; then

    log "group '$GITLAB_GROUP' not found"
    exit 0
fi
delete "$GITLAB_URL/api/v4/groups/$GROUP_ID" "$TOKEN"
log "group '$GITLAB_GROUP' deleted"

#============================#
log 'done'
